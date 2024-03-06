# frozen_string_literal: true

require "spec_helper"

require "bucket_store/disk"

RSpec.describe BucketStore::Disk do
  subject(:instance) { described_class.new(base_dir) }

  let(:bucket) { "bucket" }
  let!(:base_dir) { Dir.mktmpdir("disk-adapter-test") }

  let(:original_content) { "world" }
  let(:file) { StringIO.new(original_content) }
  let(:output_file) { StringIO.new }
  let(:downloaded_content) { output_file.string }

  after do
    FileUtils.remove_entry(base_dir)
  end

  describe "#upload!" do
    it "uploads the given content" do
      instance.upload!(bucket: bucket, key: "hello", file: file)

      instance.download(bucket: bucket, key: "hello", file: output_file)

      expect(downloaded_content).to eq("world")
    end

    context "when uploading over a key that already exists" do
      before { instance.upload!(bucket: bucket, key: "hello", file: file) }

      it "overrides the content" do
        instance.upload!(bucket: bucket, key: "hello", file: StringIO.new("planet"))

        instance.download(bucket: bucket, key: "hello", file: output_file)

        expect(downloaded_content).to eq("planet")
      end
    end

    context "when given a relative path" do
      let!(:base_dir) do
        Dir.mkdir("./.spec-temp")
        "./.spec-temp"
      end

      it "puts the content in the right directory" do
        instance.upload!(bucket: bucket, key: "hello", file: file)

        instance.download(bucket: bucket, key: "hello", file: output_file)

        expect(downloaded_content).to eq("world")
      end
    end

    context "when given a key with invalid chars" do
      it "sanitizes the filename" do
        instance.upload!(bucket: bucket, key: "this is % invalid", file: StringIO.new("%%%%"))

        expect(instance.list(bucket: bucket, key: "", page_size: 1000).first).to match(
          bucket: bucket,
          keys: ["this is _ invalid"],
        )
      end
    end
  end

  describe "#download" do
    context "when the key does not exist" do
      it "raises an error" do
        expect { instance.download(bucket: bucket, key: "unknown", file: output_file) }.
          to raise_error(Errno::ENOENT, /No such file or directory/)
      end
    end

    context "when the key has been uploaded" do
      before { instance.upload!(bucket: bucket, key: "hello", file: file) }

      it "returns the uploaded content" do
        instance.download(bucket: bucket, key: "hello", file: output_file)

        expect(downloaded_content).to eq("world")
      end

      context "but we try to fetch it from a different bucket" do
        it "raises an error" do
          expect { instance.download(bucket: "anotherbucket", key: "hello", file: output_file) }.
            to raise_error(Errno::ENOENT, /No such file or directory/)
        end
      end
    end

    context "when attempting to traverse outside of the bucket boundaries" do
      it "raises an error" do
        expect do
          instance.download(bucket: bucket, key: "../../../../../../etc/passwd", file: output_file)
        end.
          to raise_error(ArgumentError, /Directory traversal out of bucket boundaries/)
      end
    end
  end

  describe "#list" do
    context "when the bucket is empty" do
      it "returns an empty list" do
        expect(instance.list(bucket: bucket, key: "whatever", page_size: 1000).to_a).to eq([])
      end
    end

    context "when the bucket has some keys in it" do
      before do
        instance.upload!(bucket: bucket, key: "2019-01/hello1", file: StringIO.new("world"))
        instance.upload!(bucket: bucket, key: "2019-01/hello2", file: StringIO.new("world"))
        instance.upload!(bucket: bucket, key: "2019-01/hello3", file: StringIO.new("world"))
        instance.upload!(bucket: bucket, key: "2019-02/hello", file: StringIO.new("world"))
        instance.upload!(bucket: bucket, key: "2019-03/hello", file: StringIO.new("world"))
      end

      context "and we provide a matching prefix" do
        it "returns only the matching items" do
          expect(instance.list(bucket: bucket, key: "2019-01", page_size: 1000).first).to match(
            bucket: bucket,
            keys: match_array(%w[2019-01/hello1 2019-01/hello2 2019-01/hello3]),
          )
        end
      end

      context "when the prefix doesn't match anything" do
        it "returns an empty list" do
          expect(instance.list(bucket: bucket, key: "YOLO", page_size: 1000).to_a).to eq([])
        end
      end

      it "returns a subset of the matching keys" do
        expect(instance.list(bucket: bucket, key: "2019-01", page_size: 2).first).to match(
          bucket: bucket,
          keys: have_attributes(length: 2),
        )
      end

      context "when there are multiple pages of results available" do
        it "returns an enumerable" do
          expect(instance.list(bucket: bucket, key: "2019-01", page_size: 1)).
            to be_a(Enumerable)
        end

        it "enumerates through all the pages" do
          expect(instance.list(bucket: bucket, key: "2019-01", page_size: 2).to_a).
            to contain_exactly(
              { bucket: bucket, keys: have_attributes(length: 2) },
              { bucket: bucket, keys: have_attributes(length: 1) },
            )
        end
      end
    end
  end

  describe "#delete!" do
    before { instance.upload!(bucket: bucket, key: "hello", file: file) }

    it "deletes the given content" do
      expect(instance.delete!(bucket: bucket, key: "hello")).to eq(true)

      expect { instance.download(bucket: bucket, key: "hello", file: output_file) }.
        to raise_error(Errno::ENOENT, /No such file or directory/)
    end
  end
end
