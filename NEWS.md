
# News

## v0.3.0

- `Verbosity` is now a subtype of `AbstractSet{Verbosity}`
- `Verbosity` now implements the iteration interface
- Implement `instances(::Type{Verbosity})`
- Fix implementation of `symdiff(::Verbosity, ::Verbosity...)` and `setdiff(::Verbosity, ::Verbosity...)`.
