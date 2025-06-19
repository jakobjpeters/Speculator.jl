
"""
    Verbosity <: AbstractSet{Verbosity}

A flag that determine what logging statements are shown during [`speculate`](@ref).

This is modelled as a set, where [`silent`](@ref) is the empty set.
The component sets are [`debug`](@ref), [`review`](@ref), and [`warn`](@ref).

# Interface

This type implements the iteration and part of the `AbstractSet` interface.

- `hash(::Verbosity,\u00A0::UInt)`
- `instances(::Type{Verbosity})`
- `intersect(::Verbosity,\u00A0::Verbosity...)`
- `issubset(::Verbosity,\u00A0::Verbosity)`
- `iterate(::Verbosity,\u00A0::Vector{Verbosity})`
- `iterate(::Verbosity)`
- `length(::Verbosity)`
- `setdiff(::Verbosity,\u00A0::Verboosity...)`
- `show(::IO,\u00A0MIME"text/plain",\u00A0::Verbosity)`
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
struct Verbosity <: AbstractSet{Verbosity}
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

hash(verbosity::Verbosity, code::UInt) = hash((Verbosity, verbosity.value), code)

instances(::Type{Verbosity}) = (silent, debug, review, warn)

intersect(verbosity::Verbosity, verbosities::Verbosity...) = combine(&, verbosity, verbosities...)

issubset(verbosity::Verbosity, _verbosity::Verbosity) = is_subset(
    verbosity.value, _verbosity.value
)

function iterate(verbosity::Verbosity, components::Vector{Verbosity})
    while true
        if isempty(components) break
        else
            component = pop!(components)
            component ⊆ verbosity && return component, components
        end
    end
end
iterate(verbosity::Verbosity) = Base.iterate(verbosity, collect(tail(instances(Verbosity))))

length(verbosity::Verbosity) = count_ones(verbosity.value)

setdiff(verbosity::Verbosity, verbosities::Verbosity...) = verbosity ∩ _Verbosity(
    ~union(silent, verbosities...).value
)

function show(io::IO, verbosity::Verbosity)
    if verbosity == silent print(io, "silent")
    else
        names = Symbol[]

        for (_verbosity, name) ∈ (debug => :debug, review => :review, warn => :warn)
            _verbosity ⊆ verbosity && push!(names, name)
        end

        join(io, names, " ∪ ")
    end
end
function show(io::IO, ::MIME"text/plain", verbosity::Verbosity)
    show_type = !(Verbosity <: get(io, :typeinfo, Union{}))

    if show_type && length(verbosity) > 1
        print(io, '(')
        show(io, verbosity)
        print(io, ')')
    else show(io, verbosity)
    end

    if show_type print(io, "::", Verbosity) end
end

symdiff(verbosity::Verbosity, verbosities::Verbosity...) = combine(⊻, verbosity, verbosities...)

union(verbosity::Verbosity, verbosities::Verbosity...) = combine(|, verbosity, verbosities...)
