# frozen_string_literal: true

require "spec_helper"

RSpec.describe FileStorage do
  describe "#for" do
    context "when given an invalid adapter" do
      let(:key) { "invalid://bucket/path" }

      it "raises an error" do
        expect { described_class.for(key) }.
          to raise_error(RuntimeError, /Unknown adapter/i)
      end
    end

    context "when the adapter is valid" do
      let(:fs) { described_class.for(key) }

      context "and is the inmemory adapter" do
        let(:key) { "inmemory://bucket/path/to/thing" }

        it "configures the adapter correctly" do
          expect(fs.adapter_type).to eq(:inmemory)
          expect(fs.bucket).to eq("bucket")
          expect(fs.key).to eq("path/to/thing")
        end
      end

      context "and is the google cloud storage adapter" do
        before do
          allow(FileStorage::Gcs).to receive(:build).and_return(double)
        end

        let(:key) { "gs://bucket/path/to/thing" }

        it "configures the adapter correctly" do
          expect(fs.adapter_type).to eq(:gs)
          expect(fs.bucket).to eq("bucket")
          expect(fs.key).to eq("path/to/thing")
        end
      end
    end

    describe "#filename" do
      subject { described_class.for(key).filename }

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
          described_class.for("inmemory://bucket/file1.json").upload!("content1")
          described_class.for("inmemory://bucket/file2.json").upload!("content2")
        end

        it "returns all the files in the bucket" do
          expect(described_class.for("inmemory://bucket/").list).to match_array([
            "inmemory://bucket/file1.json", "inmemory://bucket/file2.json"
          ])
        end

        context "but the URI does not have a trailing /" do
          it "returns all the files in the bucket" do
            expect(described_class.for("inmemory://bucket").list).to match_array([
              "inmemory://bucket/file1.json", "inmemory://bucket/file2.json"
            ])
          end
        end
      end
    end

    describe "#download" do
      before do
        described_class.for("inmemory://bucket/file1").upload!("content1")
        described_class.for("inmemory://bucket/file2").upload!("content2")
      end

      it "downloads the given file" do
        expect(described_class.for("inmemory://bucket/file1").download).
          to match(hash_including(content: "content1"))
      end

      context "when we try to download a bucket" do
        it "raises an error" do
          expect { described_class.for("inmemory://bucket").download }.
            to raise_error(ArgumentError, /key cannot be empty/i)
        end
      end
    end

    describe "#upload!" do
      it "uploads the given file" do
        expect(described_class.for("inmemory://bucket/file1").upload!("hello")).
          to eq("inmemory://bucket/file1")
      end

      context "when we try to download a bucket" do
        it "raises an error" do
          expect { described_class.for("inmemory://bucket").upload!("content") }.
            to raise_error(ArgumentError, /key cannot be empty/i)
        end
      end
    end
  end
end
