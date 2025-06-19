
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

    global _Verbosity(value::Integer) = new(value)
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
const silent = _Verbosity(0)

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
const debug = _Verbosity(1)

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
const review = _Verbosity(2)

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
const warn = _Verbosity(4)

combine(f, verbosity::Verbosity, verbosities::Verbosity...) = _Verbosity(reduce(
    (value, _verbosity) -> f(value, _verbosity.value), verbosities; init = verbosity.value
))

intersect(verbosity::Verbosity, verbosities::Verbosity...) = combine(&, verbosity, verbosities...)

isdisjoint(verbosity::Verbosity, _verbosity::Verbosity) = isempty(verbosity ∩ _verbosity)

isempty(verbosity::Verbosity) = verbosity == silent

issetequal(verbosity::Verbosity, _verbosity::Verbosity) = verbosity == _verbosity

issubset(verbosity::Verbosity, _verbosity::Verbosity) = is_subset(
    verbosity.value, _verbosity.value
)

setdiff(verbosity::Verbosity, verbosities::Verbosity...) = verbosity ∩ _Verbosity(
    ~union(silent, verbosities...).value
)

function show(io::IO, verbosity::Verbosity)
    if isempty(verbosity) print(io, "silent")
    else
        names = Symbol[]

        for (_verbosity, name) ∈ (debug => :debug, review => :review, warn => :warn)
            _verbosity ⊆ verbosity && push!(names, name)
        end

        if length(names) == 1 print(io, only(names))
        else
            print(io, '(')
            join(io, names, " ∪ ")
            print(io, ')')
        end
    end

    print(io, "::", Verbosity)
end

symdiff(verbosity::Verbosity, verbosities::Verbosity...) = combine(⊻, verbosity, verbosities...)

union(verbosity::Verbosity, verbosities::Verbosity...) = combine(|, verbosity, verbosities...)
