
@flag Verbosity debug review warn

@doc """
    Verbosity

Flags that determine what logging statements are shown during [`speculate`](@ref).

The base flags are [`none`](@ref), [`warn`](@ref), [`review`](@ref), and [`debug`](@ref).
Elements may be combined using `|`.

# Interface

- `|(::Verbosity,\u00A0::Verbosity)`
- `in(::Verbosity,\u00A0::Verbosity)`
- `show(::IO,\u00A0::Verbosity)`

# Examples

```jldoctest
julia> none | warn
warn::Verbsosity

julia> review | debug
(review | debug)::Verbosity
```
""" Verbosity

@doc """
    none

An element of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show no logging statements.

# Examples

```jldoctest
julia> none
none::Verbosity
```
""" none

@doc """
    warn

An element of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
""" warn

@doc """
    review

An element of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show the total number of values that have been speculated.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" review

@doc """
    debug

An element of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show each successful call to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" debug
