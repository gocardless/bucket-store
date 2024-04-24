v0.7.0
------
- Lazily load AWS/GCS SDK's

v0.6.0
------
- [BREAKING] Remove support for Ruby 2.6
- Add support for streaming uploads / downloads

v0.5.0
------
- Support escaping of URI keys. Fixes #46.
- Slightly improve the performance of `.exists`

v0.4.0
------
- Add an `.exists?` method that returns `true`/`false` depending on whether a given
  key exists or not.

v0.3.0
------
- Add support for S3

v0.2.0
------

- [BREAKING] Explicitly raise a `KeyParseException` when the argument of `.for` is invalid
- Remove a dependency on a non-public logging gem and allow callers to configure
  any logger they like via a `Configuration` class.
