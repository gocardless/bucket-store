# BucketStore

An abstraction layer on the top of file cloud storage systems such as Google Cloud
Storage or S3. This module exposes a generic interface that allows interoperability
between different storage options. Callers don't need to worry about the specifics
of where and how a file is stored and retrieved as long as the given key is valid.

Keys within the `BucketStorage` are URI strings that can universally locate an object
in the given provider. A valid key example would be
`gs://a-gcs-bucket/file/path.json`.

## Usage
This library is distributed as a Ruby gem, and we recommend adding it to your Gemfile:

```ruby
gem "bucket_store"
```

Some attributes can be configured via `BucketStore.configure`. If using Rails, you want to
add a new initializer for `BucketStore`. Example:

```ruby
BucketStore.configure do |config|
  config.logger = Logger.new($stderr)
end
```

If using RSpec, you'll probably want to add this line to RSpec's config block (see
the *Adapters* section for more details):

```ruby
config.before { BucketStore::InMemory.reset! }
```

For our policy on compatibility with Ruby versions, see [COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Design and Architecture
The main principle behind `BucketStore` is that each resource or group of resources must
be unequivocally identifiable by a URI. The URI is always composed of three parts:

- the "adapter" used to fetch the resource (see "adapters" below)
- the "bucket" where the resource lives
- the path to the resource(s)

As an example, all the following are valid URIs:

- `gs://gcs-bucket/path/to/file.xml`
- `inmemory://bucket/separator/file.xml`
- `disk://hello/path/to/file.json`

Even though `BucketStore`'s main goal is to be an abstraction layer on top of systems such
as S3 or Google Cloud Storage where the "path" to a resource is in practice a unique
identifier as a whole (i.e. the `/` is not a directory separator but rather part of the
key's name), we assume that clients will actually want some sort of hierarchical
separation of resources and assume that such separation is achieved by defining each
part of the hierarchy via `/`.

This means that the following are also valid URIs in `BucketStore` but they refer to
all the resources under that specific hierarchy:

- `gs://gcs-bucket/path/subpath/`
- `inmemory://bucket/separator/`
- `disk://hello/path`

## Configuration
`BucketStore` exposes some configurable attributes via `BucketStore.configure`. If
necessary this should be called at startup time before any other method is invoked.

- `logger`: custom logger class. By default, logs will be sent to stdout.

## Adapters

`BucketStore` comes with 4 built-in adapters:

- `gs`: the Google Cloud Storage adapter
- `s3`: the S3 adapter
- `disk`: a disk-based adapter
- `inmemory`: an in-memory store

### GS adapter
This is the adapter for Google Cloud Storage. `BucketStore` assumes that the  authorisation
for accessing the resources has been set up outside of the gem.

### S3 adapter
This is the adapter for S3. `BucketStore` assumes that the authorisation for accessing
the resources has been set up outside of the gem (see also
https://docs.aws.amazon.com/sdk-for-ruby/v3/api/index.html#Configuration).

### Disk adapter
A disk-backed key-value store. This adapter will create a temporary directory where
all the files will be written into/read from. The base directory can be explicitly
defined by setting the `DISK_ADAPTER_BASE_DIR` environment variable, otherwise a temporary
directory will be created.

### In-memory adapter
An in-memory key-value storage. This works just like the disk adapter, except that
the content of all the files is stored in memory, which is particularly useful for
testing. Note that content added to this adapter will persist for the lifetime of
the application as it's not possible to create different instances of the same adapter.
In general, this is not what's expected during testing where the content of the bucket
should be reset between different tests. The adapter provides a way to easily reset the
content though via a `.reset!` method. In RSpec this would translate to adding this line
in the `spec_helper`:

```ruby
config.before { BucketStore::InMemory.reset! }
```

## BucketStore vs ActiveStorage

ActiveStorage is a common framework to access cloud storage systems that is included in
the ActiveSupport library. In general, ActiveStorage provides a lot more than BucketStore
does (including many more adapters) however the two libraries have different use cases
in mind:

- ActiveStorage requires you to define every possible bucket you're planning to use
  ahead of time in a YAML file. This works well for most cases, however if you plan to
  use a lot of buckets this soon becomes impractical. We think that BucketStore approach
  works much better in this case.
- BucketStore does not provide ways to manipulate the content whereas ActiveStorage does.
  If you plan to apply transformations to the content before uploading or after
  downloading them, then probably ActiveStorage is the library for you. With that said,
  it's still possible to do these transformations outside of BucketStore and in fact we've
  found the explicitness of this approach a desirable property.
- BucketStore approach makes any resource on a cloud storage system uniquely identifiable
  via a single URI, which means normally it's enough to pass that string around different
  systems to be able to access the resource without ambiguity. As the URI also includes
  the adapter, it's possible for example to download a `disk://dir/input_file` and
  upload it to a `gs://bucket/output_file` all going through a single interface.
  ActiveStorage is instead focused on persisting an equivalent reference on a Rails model.
  If your application does not use Rails, or does not need to persist the reference or
  just requires more flexibility in general, then BucketStore is probably the library for
  you.


## Examples

### Uploading a file to a bucket
```ruby
BucketStore.for("inmemory://bucket/path/file.xml").upload!("hello world")
=> "inmemory://bucket/path/file.xml"
```

### Accessing a file in a bucket
```ruby
BucketStore.for("inmemory://bucket/path/file.xml").download
=> {:bucket=>"bucket", :key=>"path/file.xml", :content=>"hello world"}
```

### Listing all keys under a prefix
```ruby
BucketStore.for("inmemory://bucket/path/").list
=> ["inmemory://bucket/path/file.xml"]
```

### Delete a file
```ruby
BucketStore.for("inmemory://bucket/path/file.xml").delete!
=> true
```

## Development

### Running tests
BucketStore comes with both unit and integration tests. While unit tests can be run by simply
executing `bundle exec rspec`, integration tests require running minio locally. We provide an
helper script (`scripts/run-minio.sh`) that spins up a pre-configured docker container with
a single test bucket. Once minio has started, integration tests can be executed with
`bundle exec rspec --tag integration`.

## License & Contributing

* BucketStore is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
* Bug reports and pull requests are welcome on GitHub at https://github.com/gocardless/bucket-store.

GoCardless ♥ open source. If you do too, come [join us](https://gocardless.com/about/careers/).
test
