
"""
    Verbosity

A flag that determine what logging statements are shown during [`speculate`](@ref).

This is modelled as a set, where [`silent`](@ref) is the empty set.
The non-empty component flags are [`debug`](@ref), [`review`](@ref), and [`warn`](@ref).

# Interface

This type implements part of the `AbstractSet` interface.

- `intersect(::Verbosity,\u00A0::Verbosity...)`
- `isdisjoint(::Verbosity,\u00A0::Verbosity)`
- `isempty(::Verbosity)`
- `issetequal(::Verbosity,\u00A0::Verbosity)`
- `issubset(::Verbosity,\u00A0::Verbosity)`
- `setdiff(::Verbosity,\u00A0::Verboosity...)`
- `show(::IO,\u00A0::Verbosity)`
- `symdiff(::Verbosity,\u00A0::Verbosity...)`
- `union(::Verbosity,\u00A0::Verbosity...)`

# Examples

```jldoctest
julia> silent
silent::Verbosity

julia> debug ∪ review
(debug ∪ review)::Verbosity

julia> debug ⊆ debug ∪ review
true

julia> debug ⊆ warn
false
```
"""
struct Verbosity
    value::UInt8

    global verbosity(x::Union{Int, UInt8}) = new(x)

    Base.union(v::Verbosity, vs::Verbosity...) = new(reduce(
        (value, _v) -> value | _v.value, vs;
    init = v.value))

    Base.intersect(v::Verbosity, vs::Verbosity...) = new(reduce(
        (value, _v) -> value & _v.value, vs;
    init = v.value))

    Base.setdiff(v::Verbosity, vs::Verbosity...) = new(v.value & ~union(vs...).value)
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
All warnings are considered a bug,
and should be filed as an issue in Speculator.jl.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
"""
const warn = verbosity(4)

isdisjoint(v::Verbosity, _v::Verbosity) = isempty(v ∩ _v)

isempty(v::Verbosity) = v == silent

issetequal(v::Verbosity, _v::Verbosity) = v == _v

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
            join(io, names, " ∪ ")
            print(io, ')')
        end
    end

    print(io, "::", Verbosity)
end

function symdiff(v::Verbosity, vs::Verbosity...)
    counts = Dict(debug => 0, review => 0, warn => 0)

    for verbosity in keys(counts)
        for _v in [v, vs...]
            (counts[verbosity] += verbosity ⊆ _v) > 1 && break
        end
    end

    reduce(union, keys(filter!(==(1) ∘ last, counts)); init = silent)
end
