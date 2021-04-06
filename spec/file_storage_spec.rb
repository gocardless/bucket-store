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
  end
end
