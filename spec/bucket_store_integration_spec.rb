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
    context "using #{base_bucket_uri}" do
      before do
        described_class.for(base_bucket_uri).list.each do |path|
          described_class.for(path).delete!
        end
      end

      it "returns an empty bucket when no files are uploaded" do
        expect(described_class.for(base_bucket_uri.to_s).list.to_a.size).to eq(0)
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
        described_class.for(base_bucket_uri.to_s).list.each do |key|
          described_class.for(key).delete!
        end
        expect(described_class.for(base_bucket_uri.to_s).list.to_a.size).to eq(0)
      end

      context "using the streaming interface" do
        it "supports large file downloads" do
          # Upload a large file
          large_file_content = "Z" * 1024 * 1024 * 10 # 10Mb
          described_class.
            for("#{base_bucket_uri}/large.txt").
            upload!(large_file_content)

          # Streaming downloads should return a chunked response
          rebuilt_large_file =
            described_class.for("#{base_bucket_uri}/large.txt").
              stream.
              download.
              map { |_meta, chunk| chunk }.
              join

          expect(rebuilt_large_file.size).to eq(large_file_content.size)
          expect(rebuilt_large_file).to eq(large_file_content)
        end

        it "allows downloads of individual small chunks" do
          described_class.
            for("#{base_bucket_uri}/large.txt").
            upload!("1234567890")

          chunks = described_class.for("#{base_bucket_uri}/large.txt").
            stream.
            download(chunk_size: 1).
            to_a

          expect(chunks.size).to eq(10)
          expect(chunks.map { |_meta, chunk| chunk }).to match_array(
            %w[1 2 3 4 5 6 7 8 9 0],
          )
        end

        it "supports large file uploads" do
          # Upload a large file
          large_file_chunks = ["Z" * 1024 * 1024] * 10 # 10Mb
          large_file_content = large_file_chunks.join

          described_class.
            for("#{base_bucket_uri}/large.txt").
            stream.
            upload do |uploader|
              large_file_chunks.
                each do |chunk|
                  uploader.upload!(*chunk)
                end
            end

          # Streaming downloads should return a chunked response
          downloaded_large_file =
            described_class.for("#{base_bucket_uri}/large.txt").
              download[:content]

          expect(downloaded_large_file.size).to eq(large_file_content.size)
          expect(downloaded_large_file).to eq(large_file_content)
        end

        it "allows uploads of individual small chunks" do
          described_class.
            for("#{base_bucket_uri}/large.txt").
            stream.
            upload do |uploader|
            "1234567890".chars.each { |content| uploader.upload!(content) }
          end

          expect(described_class.for("#{base_bucket_uri}/large.txt").download[:content]).
            to eq("1234567890")
        end
      end
    end
  end

  include_examples "adapter integration", "inmemory://bucket"
  include_examples "adapter integration", "disk://bucket"
  include_examples "adapter integration", "s3://bucket"
  include_examples "adapter integration", "gs://bucket"
end
