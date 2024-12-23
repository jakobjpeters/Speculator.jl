
"""
    Verbosity

A flag that determine what logging statements are shown during [`speculate`](@ref).

The component flags are [`silent`](@ref), [`debug`](@ref), [`review`](@ref), and [`warn`](@ref).

# Interface

- `|(::Verbosity,\u00A0::Verbosity)`
    - Combine the verbosities such that each satisfies `issubset` with the returned verbosity.
- `issubset(::Verbosity,\u00A0::Verbosity)`
    - Check whether each flag of the first verbosity is a component of the second verbosity.
- `show(::IO,\u00A0::Verbosity)`

# Examples

```jldoctest
julia> silent
silent::Verbosity

julia> debug | review
(debug | review)::Verbosity

julia> debug ⊆ debug | review
true

julia> debug ⊆ warn
false
```
"""
struct Verbosity
    value::UInt8

    global verbosity(x::Union{Int, UInt8}) = new(x)

    Base.:|(v::Verbosity, _v::Verbosity) = new(v.value | _v.value)
end

"""
    silent::Verbosity

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) will not show any logging statements.

# Examples

```jldoctest
julia> silent
silent::Verbosity
```
"""
const silent = verbosity(0)

"""
    debug::Verbosity

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) will show each successful call to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
"""
const debug = verbosity(1)

"""
    review::Verbosity

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will show a summary of the number of methods generated,
the number of generic methods found, and the duration.
If `dry = false`, this also shows the number of generated
methods that were compiled, skipped, and warned.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
"""
const review = verbosity(2)

"""
    warn::Verbosity

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
"""
const warn = verbosity(4)

issubset(v::Verbosity, _v::Verbosity) = is_subset(v.value, _v.value)

function show(io::IO, v::Verbosity)
    if v == silent print(io, "silent")
    else
        names = Symbol[]

        debug ⊆ v && push!(names, :debug)
        review ⊆ v && push!(names, :review)
        warn ⊆ v && push!(names, :warn)

        if length(names) == 1 print(io, only(names))
        else
            print(io, '(')
            join(io, names, " | ")
            print(io, ')')
        end
    end

    print(io, "::", Verbosity)
end
