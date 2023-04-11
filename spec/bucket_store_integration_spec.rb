# frozen_string_literal: true

require "spec_helper"

require "aws-sdk-s3"

RSpec.describe BucketStore, :integration do
  before do
    # Setup AWS connectivity to minio
    Aws.config.update(
      endpoint: "http://localhost:9000",
      region: "us-east-1",

      # default credentials for minio
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",

      # required for minio as otherwise the client will try to resolve `bucketname.localhost:9000`
      force_path_style: true,
    )

    # Setup GCS connectivity to the simulator
    ENV["STORAGE_EMULATOR_HOST"] ||= "http://localhost:9023/"
  end

  shared_examples "adapter integration" do |base_bucket_uri|
    before do
      described_class.for(base_bucket_uri).list.each do |path|
        described_class.for(path).delete!
      end
    end

    it "has a consistent interface" do
      # Write 201 files
      file_list = []
      201.times do |i|
        filename = "file#{(i + 1).to_s.rjust(3, '0')}.txt"
        file_list << filename

        # the body of the file is the filename itself
        described_class.for("#{base_bucket_uri}/prefix/#{filename}").upload!(filename)
      end

      # Add some files with spaces
      described_class.for("#{base_bucket_uri}/prefix/i have a space.txt").
        upload!("i have a space.txt")
      described_class.for("#{base_bucket_uri}/prefix/another space.txt").
        upload!("another space.txt")

      file_list << "i have a space.txt"
      file_list << "another space.txt"

      # List with prefix should only return the matching files
      expect(described_class.for("#{base_bucket_uri}/prefix/file1").list.to_a.size).to eq(100)
      expect(described_class.for("#{base_bucket_uri}/prefix/file2").list.to_a.size).to eq(2)
      expect(described_class.for("#{base_bucket_uri}/prefix/").list.to_a.size).to eq(203)

      # List (without prefixes) should return everything
      expect(described_class.for(base_bucket_uri.to_s).list.to_a).
        to match_array(file_list.map { |filename| "#{base_bucket_uri}/prefix/#{filename}" })

      # We know the content of the file, we can check `.download` returns it as expected
      all_files = file_list.map do |filename|
        [filename, "#{base_bucket_uri}/prefix/#{filename}"]
      end
      all_files.each do |content, key|
        expect(described_class.for(key).download[:content]).to eq(content)
      end

      # Delete all the files, the bucket should be empty afterwards
      file_list.map { |filename| "#{base_bucket_uri}/prefix/#{filename}" }.each do |key|
        described_class.for(key).delete!
      end
      expect(described_class.for(base_bucket_uri.to_s).list.to_a.size).to eq(0)
    end
  end

  # We don't test GCS as there's no sensible way of running a local simulator
  include_examples "adapter integration", "inmemory://bucket"
  include_examples "adapter integration", "disk://bucket"
  include_examples "adapter integration", "s3://bucket"
  include_examples "adapter integration", "gs://bucket"
end
