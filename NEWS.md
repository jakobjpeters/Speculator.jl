
# News

## v0.3.0

- No longer warns when speculation is not ran
- Fix error printing callable objects with multiple type parameters
- Better log formatting
- `speculate`
    - Use `compile = true` instead of `dry = false` to compile generated signatures
- `Verbosity`
    - `debug` has been split into `compile` and `pass`
    - Is now a subtype of `AbstractSet{Verbosity}`
    - Now implements the iteration interface
    - Implement `instances(::Type{Verbosity})`
    - Fix implementation of `symdiff(::Verbosity, ::Verbosity...)` and `setdiff(::Verbosity, ::Verbosity...)`.
