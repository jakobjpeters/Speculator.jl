
@flag Verbosity debug review warn

@doc """
    Verbosity

A flag that determine what logging statements are shown during [`speculate`](@ref).

The base flags are [`warn`](@ref), [`review`](@ref), and [`debug`](@ref).

# Interface

- `|(::Verbosity,\u00A0::Verbosity)`
    - Combine the verbosities such that each satisfies `issubset` with the resulting verbosity.
- `issubset(::Verbosity,\u00A0::Verbosity)`
    - Check whether each flag of the first verbosity is a flag of the second verbosity.
- `show(::IO,\u00A0::Verbosity)`

# Examples

```jldoctest
julia> debug
debug::Verbsosity

julia> review | warn
(review | warn)::Verbosity

julia> review ⊆ review
true

julia> review ⊆ warn
false
```
""" Verbosity

@doc """
    none

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show no logging statements.

# Examples

```jldoctest
julia> none
none::Verbosity
```
""" none

@doc """
    warn

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
""" warn

@doc """
    review

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show the total number of values that have been speculated.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" review

@doc """
    debug

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show each successful call to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" debug
