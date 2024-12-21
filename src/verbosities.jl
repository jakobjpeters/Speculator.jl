
"""
    Verbosity

A flag that determine what logging statements are shown during [`speculate`](@ref).

The base flags are [`silent`](@ref), [`debug`](@ref), [`review`](@ref), and [`warn`](@ref).

# Interface

- `|(::Verbosity,\u00A0::Verbosity)`
    - Combine the verbosities such that each satisfies `issubset` with the resulting verbosity.
- `issubset(::Verbosity,\u00A0::Verbosity)`
    - Check whether each flag of the first verbosity is a flag of the second verbosity.
- `show(::IO,\u00A0::Verbosity)`

# Examples

```jldoctest
julia> silent
silent::Verbsosity

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

    global verbosity(x) = new(x)

    Base.:|(v::Verbosity, _v::Verbosity) = new(v.value, _v.value)
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
will show the total number of values that have been speculated.

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

issubset(v::Verbosity, _v::Verbosity) = issubset(v.value, _v.value)

show(io::IO, v::Verbosity) =
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

        print(io, "::", Verbosity)
    end
