# frozen_string_literal: true

require "spec_helper"

require "file_storage/uri_builder"

RSpec.describe FileStorage::UriBuilder do
  describe "#sanitize" do
    subject { described_class.sanitize(input) }

    context "when there's nothing to replace" do
      let(:input) { "everything is good" }

      it { is_expected.to(eq(input)) }
    end

    context "when the input contains characters we cannot process" do
      let(:input) { "everything is {not} go%od <enough>" }

      it { is_expected.to(eq("everything is __not__ go__od __enough__")) }

      context "and we have specified a different replacement" do
        subject { described_class.sanitize(input, "!!") }

        it { is_expected.to(eq("everything is !!not!! go!!od !!enough!!")) }
      end
    end
  end
end
