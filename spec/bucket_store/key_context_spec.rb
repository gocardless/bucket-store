# frozen_string_literal: true

require "spec_helper"

require "bucket_store/key_context"

RSpec.describe BucketStore::KeyContext do
  describe ".parse" do
    context "when given an invalid key" do
      let(:key) { "invalid" }

      it "raises an error" do
        expect { described_class.parse(key) }.
          to raise_error(described_class::KeyParseException)
      end
    end

    context "when missing the scheme" do
      let(:key) { "bucket/path" }

      it "raises an error" do
        expect { described_class.parse(key) }.
          to raise_error(described_class::KeyParseException)
      end
    end

    context "when given a valid parseable key" do
      let(:key) { "scheme://bucket/hello/world" }
      let(:instance) { described_class.parse(key) }

      it "parses the key" do
        expect(instance.adapter).to eq("scheme")
        expect(instance.bucket).to eq("bucket")
        expect(instance.key).to eq("hello/world")
      end

      context "with an empty key" do
        let(:key) { "scheme://bucket" }

        it "returns an empty key" do
          expect { instance }.to_not raise_error

          expect(instance.adapter).to eq("scheme")
          expect(instance.bucket).to eq("bucket")
          expect(instance.key).to eq("")
        end
      end

      context "with characters that would need to be escaped" do
        context "with a space" do
          let(:key) { "scheme://bucket/hello world" }

          it "parses the key" do
            expect(instance.adapter).to eq("scheme")
            expect(instance.bucket).to eq("bucket")
            expect(instance.key).to eq("hello world")
          end
        end

        context "with a %" do
          let(:key) { "scheme://bucket/hello%world" }

          it "parses the key" do
            expect(instance.adapter).to eq("scheme")
            expect(instance.bucket).to eq("bucket")
            expect(instance.key).to eq("hello%world")
          end
        end
      end
    end
  end
end
