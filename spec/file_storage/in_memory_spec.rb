# frozen_string_literal: true

require "spec_helper"

require "file_storage/in_memory"

RSpec.describe FileStorage::InMemory do
  let(:instance) { described_class.new }

  let(:bucket) { "bucket" }

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
  end

  describe "#download" do
    context "when the key does not exist" do
      it "raises an error" do
        expect { instance.download(bucket: bucket, key: "unknown") }.
          to raise_error(KeyError, /key not found/)
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
          expect(instance.list(bucket: bucket, key: "whatever", page_size: 1000)).to eq(
            bucket: bucket,
            keys: [],
          )
        end
      end
    end
  end

  describe "#list" do
    context "when the bucket is empty" do
      it "returns an empty list" do
        expect(instance.list(bucket: bucket, key: "whatever", page_size: 1000)).to eq(
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
          expect(instance.list(bucket: bucket, key: "2019-01", page_size: 1000)).to match(
            bucket: bucket,
            keys: match_array(%w[2019-01/hello1 2019-01/hello2 2019-01/hello3]),
          )
        end
      end

      context "when the prefix doesn't match anything" do
        it "returns an empty list" do
          expect(instance.list(bucket: bucket, key: "YOLO", page_size: 1000)).to match(
            bucket: bucket,
            keys: [],
          )
        end
      end

      context "and we request fewer keys than they are available" do
        it "returns a subset of the matching keys" do
          expect(instance.list(bucket: bucket, key: "2019-01", page_size: 2)).to match(
            bucket: bucket,
            keys: have_attributes(length: 2),
          )
        end
      end
    end
  end

  describe "#reset!" do
    let(:bucket2) { "bucket2" }

    context "when there's some content" do
      before do
        instance.upload!(bucket: bucket, key: "2019-01/hello1", content: "world")
        instance.upload!(bucket: bucket, key: "2019-01/hello2", content: "world")
        instance.upload!(bucket: bucket, key: "2019-01/hello3", content: "world")
        instance.upload!(bucket: bucket2, key: "2019-02/hello", content: "world")
        instance.upload!(bucket: bucket2, key: "2019-03/hello", content: "world")
      end

      it "resets all the buckets" do
        instance.reset!

        expect { instance.download(bucket: bucket, key: "2019-01/hello1") }.
          to raise_error(KeyError, /key not found/)
        expect { instance.download(bucket: bucket, key: "2019-01/hello2") }.
          to raise_error(KeyError, /key not found/)
        expect { instance.download(bucket: bucket, key: "2019-01/hello3") }.
          to raise_error(KeyError, /key not found/)
        expect { instance.download(bucket: bucket2, key: "2019-02/hello") }.
          to raise_error(KeyError, /key not found/)
        expect { instance.download(bucket: bucket2, key: "2019-03/hello") }.
          to raise_error(KeyError, /key not found/)
      end
    end
  end

  describe "#delete!" do
    before { instance.upload!(bucket: bucket, key: "hello", content: "world") }

    it "deletes the given content" do
      expect(instance.delete!(bucket: bucket, key: "hello")).to eq(true)

      expect { instance.download(bucket: bucket, key: "hello").download }.to raise_error(KeyError)
    end
  end
end
