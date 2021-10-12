# frozen_string_literal: true

require "fileutils"

module FileStorage
  class Disk
    def self.build(base_dir = ENV["DISK_ADAPTER_BASE_DIR"])
      base_dir ||= Dir.tmpdir
      Disk.new(base_dir)
    end

    def initialize(base_dir)
      @base_dir = File.expand_path(base_dir)
    end

    def upload!(bucket:, key:, content:)
      File.open(key_path(bucket, key), "w") do |file|
        file.write(content)
      end
      {
        bucket: bucket,
        key: key,
      }
    end

    def download(bucket:, key:)
      File.open(key_path(bucket, key), "r") do |file|
        {
          bucket: bucket,
          key: key,
          content: file.read,
        }
      end
    end

    def list(bucket:, key:, page_size:)
      root = Pathname.new(bucket_root(bucket))

      Dir["#{root}/**/*"].
        reject { |absolute_path| File.directory?(absolute_path) }.
        map { |full_path| Pathname.new(full_path).relative_path_from(root).to_s }.
        select { |f| f.start_with?(key) }.
        each_slice(page_size).
        map do |keys|
        {
          bucket: bucket,
          keys: keys,
        }
      end.to_enum
    end

    def delete!(bucket:, key:)
      File.unlink(key_path(bucket, key))

      true
    end

    def move!(bucket:, key:, new_bucket:, new_key:)
      FileUtils.mv(key_path(bucket, key), key_path(new_bucket, new_key))

      {
        bucket: new_bucket,
        key: new_key,
      }
    end

    private

    attr_reader :base_dir

    def bucket_root(bucket)
      path = File.join(base_dir, sanitize_filename(bucket))
      FileUtils.mkdir_p(path)
      path
    end

    def key_path(bucket, key)
      path = File.join(bucket_root(bucket), sanitize_filename(key))
      path = File.expand_path(path)

      unless path.start_with?(base_dir)
        raise ArgumentError, "Directory traversal out of bucket boundaries: #{key}"
      end

      FileUtils.mkdir_p(File.dirname(path))
      path
    end

    def sanitize_filename(filename)
      filename.gsub(%r{[^0-9A-z.\-/]}, "_")
    end
  end
end
