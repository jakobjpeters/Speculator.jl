
"""
    Verbosity <: AbstractSet{Verbosity}

A flag that determine what logging statements are shown during [`speculate`](@ref).

This is modelled as a set, where [`silent`](@ref) is the empty set.
The component sets are [`compile`](@ref), [`pass`](@ref), [`review`](@ref), and [`warn`](@ref).

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
    compile::Verbosity

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) will show each compiled method signature.

# Examples

```jldoctest
julia> compile
compile::Verbosity
```
"""
const compile = _Verbosity(1)

"""
    pass::Verbosity

A flag of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) will show each method signature that was
either previously compiled or unchecked due to `compile = false`.

# Examples

```jldoctest
julia> pass
pass::Verbosity
```
"""
const pass = _Verbosity(2)

"""
    review::Verbosity

A flag of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
will show a summary of the number of generated concrete method signatures,
the number of generic methods found, and the search duration.
If `compile = true`, this also shows the number of method
signatures that were compiled, skipped, and warned.

# Examples

```jldoctest
julia> review
review::Verbosity
```
"""
const review = _Verbosity(4)

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
const warn = _Verbosity(8)

combine(f, verbosity::Verbosity, verbosities::Verbosity...) = _Verbosity(reduce(
    (value, _verbosity) -> f(value, _verbosity.value), verbosities; init = verbosity.value
))

hash(verbosity::Verbosity, code::UInt) = hash((Verbosity, verbosity.value), code)

instances(::Type{Verbosity}) = (silent, compile, pass, review, warn)

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
iterate(verbosity::Verbosity) = Base.iterate(verbosity, collect(verbosities))

length(verbosity::Verbosity) = count_ones(verbosity.value)

setdiff(verbosity::Verbosity, verbosities::Verbosity...) = verbosity ∩ _Verbosity(
    ~union(silent, verbosities...).value
)

function details(verbosity::Verbosity)
    if verbosity == compile; :compile => :light_cyan
    elseif verbosity == pass; :pass => :light_blue
    elseif verbosity == review; :review => :light_magenta
    elseif verbosity == warn; :warn => :light_yellow
    else error("a compound `Verbosity` has no details")
    end
end

function show(io::IO, verbosity::Verbosity)
    if verbosity == silent print(io, "silent")
    else
        _details = Stateful(Iterators.map(details, verbosity ∩ (compile ∪ pass ∪ review ∪ warn)))

        for (name, color) ∈ _details
            print(io, name)
            isempty(_details) || print(io, " ∪ ")
        end
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
