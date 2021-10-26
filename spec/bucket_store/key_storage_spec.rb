# frozen_string_literal: true

require "spec_helper"

require "bucket_store/key_context"
require "bucket_store/key_storage"

RSpec.describe BucketStore::KeyStorage do
  def build_for(key)
    ctx = BucketStore::KeyContext.parse(key)

    described_class.new(adapter: ctx.adapter,
                        bucket: ctx.bucket,
                        key: ctx.key)
  end

  describe "#filename" do
    subject { build_for(key).filename }

    let(:key) { "inmemory://bucket/file_name.txt" }

    it { is_expected.to eq("file_name.txt") }

    context "when there's multiple subdirectories" do
      let(:key) { "inmemory://bucket/level1/level2/level3/level4/yolo.txt" }

      it { is_expected.to eq("yolo.txt") }
    end
  end

  describe "#list" do
    context "when we try to list the whole bucket" do
      before do
        build_for("inmemory://bucket/file1.json").upload!("content1")
        build_for("inmemory://bucket/file2.json").upload!("content2")
      end

      it "returns all the files in the bucket" do
        expect(build_for("inmemory://bucket/").list).to match_array([
          "inmemory://bucket/file1.json", "inmemory://bucket/file2.json"
        ])
      end

      it "logs the operation" do
        expect(BucketStore.logger).to receive(:info).with(
          hash_including(event: "key_storage.list_started"),
        )
        expect(BucketStore.logger).to receive(:info).with(
          hash_including(event: "key_storage.list_page_fetched"),
        )

        build_for("inmemory://bucket").list.to_a
      end

      context "but the URI does not have a trailing /" do
        it "returns all the files in the bucket" do
          expect(build_for("inmemory://bucket").list).to match_array([
            "inmemory://bucket/file1.json", "inmemory://bucket/file2.json"
          ])
        end
      end
    end
  end

  describe "#download" do
    before do
      build_for("inmemory://bucket/file1").upload!("content1")
      build_for("inmemory://bucket/file2").upload!("content2")
    end

    it "downloads the given file" do
      expect(build_for("inmemory://bucket/file1").download).
        to match(hash_including(content: "content1"))
    end

    it "logs the operation" do
      expect(BucketStore.logger).to receive(:info).with(
        hash_including(event: "key_storage.download_started"),
      )
      expect(BucketStore.logger).to receive(:info).with(
        hash_including(event: "key_storage.download_finished"),
      )

      build_for("inmemory://bucket/file1").download
    end

    context "when we try to download a bucket" do
      it "raises an error" do
        expect { build_for("inmemory://bucket").download }.
          to raise_error(ArgumentError, /key cannot be empty/i)
      end
    end
  end

  describe "#upload!" do
    it "uploads the given file" do
      expect(build_for("inmemory://bucket/file1").upload!("hello")).
        to eq("inmemory://bucket/file1")
    end

    it "logs the operation" do
      expect(BucketStore.logger).to receive(:info).with(
        hash_including(event: "key_storage.upload_started"),
      )
      expect(BucketStore.logger).to receive(:info).with(
        hash_including(event: "key_storage.upload_finished"),
      )

      build_for("inmemory://bucket/file1").upload!("hello")
    end

    context "when we try to upload a bucket" do
      it "raises an error" do
        expect { build_for("inmemory://bucket").upload!("content") }.
          to raise_error(ArgumentError, /key cannot be empty/i)
      end
    end
  end

  describe "delete!" do
    before do
      build_for("inmemory://bucket/file1").upload!("content1")
    end

    it "deletes the given file" do
      expect(build_for("inmemory://bucket/file1").delete!).to eq(true)
    end
  end
end
