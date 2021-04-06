v0.2.0
------

- [BREAKING] Explicitly raise a `KeyParseException` when the argument of `.for` is invalid
- Remove a dependency on a non-public logging gem and allow callers to configure
  any logger they like via a `Configuration` class.
