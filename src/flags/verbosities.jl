
@flag Verbosity debug review warn

@doc """
    Verbosity

A flag that determine what logging statements are shown during [`speculate`](@ref).

The base flags are [`debug`](@ref), [`review`](@ref), and [`warn`](@ref).

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

julia> review ⊆ review | warn
true

julia> review ⊆ warn
false
```
""" Verbosity

@doc """
    debug

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) will show each successful call to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" debug

@doc """
    generate

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will append the precompilation workload to the file specified by the `path` keyword parameter.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" generate

@doc """
    review

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will show the total number of values that have been speculated.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" review

@doc """
    warn

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
""" warn
