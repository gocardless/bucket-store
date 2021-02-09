# frozen_string_literal: true

require "spec_helper"

require "file_storage/disk"

RSpec.describe FileStorage::Disk do
  subject(:instance) { described_class.new(base_dir) }

  let(:bucket) { "bucket" }
  let!(:base_dir) { Dir.mktmpdir("disk-adapter-test") }

  after do
    FileUtils.remove_entry(base_dir)
  end

  describe "#upload!" do
    it "uploads the given content" do
      instance.upload!(bucket: bucket, key: "hello", content: "world")

      expect(instance.download(bucket: bucket, key: "hello")).to eq(
        bucket: bucket,
        key: "hello",
        content: "world",
      )
    end

    context "when uploading over a key that already exists" do
      before { instance.upload!(bucket: bucket, key: "hello", content: "world") }

      it "overrides the content" do
        instance.upload!(bucket: bucket, key: "hello", content: "planet")

        expect(instance.download(bucket: bucket, key: "hello")).to eq(
          bucket: bucket,
          key: "hello",
          content: "planet",
        )
      end
    end

    context "when given a relative path" do
      let!(:base_dir) do
        Dir.mkdir("./.spec-temp")
        "./.spec-temp"
      end

      it "puts the content in the right directory" do
        instance.upload!(bucket: bucket, key: "hello", content: "world")

        expect(instance.download(bucket: bucket, key: "hello")).to eq(
          bucket: bucket,
          key: "hello",
          content: "world",
        )
      end
    end
  end

  describe "#download" do
    context "when the key does not exist" do
      it "raises an error" do
        expect { instance.download(bucket: bucket, key: "unknown") }.
          to raise_error(Errno::ENOENT, /No such file or directory/)
      end
    end

    context "when the key has been uploaded" do
      before { instance.upload!(bucket: bucket, key: "hello", content: "world") }

      it "returns the uploaded content" do
        expect(instance.download(bucket: bucket, key: "hello")).to eq(
          bucket: bucket,
          key: "hello",
          content: "world",
        )
      end

      context "but we try to fetch it from a different bucket" do
        it "raises an error" do
          expect { instance.download(bucket: "anotherbucket", key: "hello") }.
            to raise_error(Errno::ENOENT, /No such file or directory/)
        end
      end
    end

    context "when attempting to traverse outside of the bucket boundaries" do
      it "raises an error" do
        expect { instance.download(bucket: bucket, key: "../../../../../../etc/passwd") }.
          to raise_error(ArgumentError, /Directory traversal out of bucket boundaries/)
      end
    end
  end

  describe "#list" do
    context "when the bucket is empty" do
      it "returns an empty list" do
        expect(instance.list(bucket: bucket, key: "whatever")).to eq(
          bucket: bucket,
          keys: [],
        )
      end
    end

    context "when the bucket has some keys in it" do
      before do
        instance.upload!(bucket: bucket, key: "2019-01/hello1", content: "world")
        instance.upload!(bucket: bucket, key: "2019-01/hello2", content: "world")
        instance.upload!(bucket: bucket, key: "2019-01/hello3", content: "world")
        instance.upload!(bucket: bucket, key: "2019-02/hello", content: "world")
        instance.upload!(bucket: bucket, key: "2019-03/hello", content: "world")
      end

      context "and we provide a matching prefix" do
        it "returns only the matching items" do
          expect(instance.list(bucket: bucket, key: "2019-01")).to match(
            bucket: bucket,
            keys: match_array(%w[2019-01/hello1 2019-01/hello2 2019-01/hello3]),
          )
        end
      end

      context "when the prefix doesn't match anything" do
        it "returns an empty list" do
          expect(instance.list(bucket: bucket, key: "YOLO")).to match(
            bucket: bucket,
            keys: [],
          )
        end
      end
    end
  end

  describe "#delete!" do
    before { instance.upload!(bucket: bucket, key: "hello", content: "world") }

    it "deletes the given content" do
      expect(instance.delete!(bucket: bucket, key: "hello")).to eq(true)

      expect { instance.download(bucket: bucket, key: "hello").download }.
        to raise_error(Errno::ENOENT, /No such file or directory/)
    end
  end
end
