# file-storage

An abstraction layer on the top of file cloud storage systems such as Google Cloud
Storage or S3. This module exposes a generic interface that allows interoperability
between different storage options. Callers don't need to worry about the specifics
of where and how a file is stored and retrieved as long as the given key is valid.

Keys within the `FileStorage` are URI strings that can universally locate an object
in the given provider. A valid key example would be 
`gs://gc-prd-nx-incoming/file/path.json`.

## Usage
In order to make use of this, you'll first need to add this gem to your `Gemfile`:

```ruby
gem 'file-storage', git: 'git@github.com:gocardless/file-storage.git'
```

## Adapters

`FileStorage` comes with 3 adapters:

- `gs`: the Google Cloud Storage adapter
- `disk`: a disk-based adapter
- `inmemory`: an in-memory store

### GS adapter
This is the Google Cloud Storage adapter and what you'll most likely wan to use in
production. `FileStorage` assumes that the authorisation for accessing the resources
has been set up outside of the gem.


### Disk adapter
A disk-backed key-value store. This adapter will create a temporary directory where
all the files will be written into/read from. The base directory can be explicitly
defined by setting the `DISK_ADAPTER_BASE_DIR` environment variable. 


### In-memory adapter
An in-memory key-value storage. This works just like the disk adapter, except that
the content of all the files is stored in memory. This is particularly useful for
testing. Note that content added to this adapter will persist for the lifetime of
the application - this means that if used in tests, content added to a random test
will be visible to all other tests unless explicitly removed. Generally this is not
what you want, so it's recommended to explicitly reset the content before every
test. In RSpec this would translate to adding this line in the `spec_helper`:

```ruby
config.before { FileStorage::InMemory.reset! }
```

## Examples

### Uploading a file to GCS
```ruby
FileStorage.for("inmemory://bucket/path/file.xml").upload!("hello world")
=> "inmemory://bucket/path/file.xml"
```

### Accessing a file on GCS
```ruby
FileStorage.for("inmemory://bucket/path/file.xml").download
=> {:bucket=>"bucket", :key=>"path/file.xml", :content=>"hello world"}
```

### Listing all keys under a prefix
```ruby
FileStorage.for("inmemory://bucket/path/").list
=> ["inmemory://bucket/path/file.xml"]
```
