
module Speculator

using Base: uniontypes
using InteractiveUtils: subtypes

export Verbosity, debug, none, speculate, warn

const __speculate = quote
    for method in methods(x)
        sig = method.sig

        if isconcretetype(sig)
            types = getfield(sig, 3)[(begin + 1):end]

            if precompile(x, ntuple(i -> types[i], length(types)))
                verbosity == debug && @info "Precompiled `$(signature(x, types))`"
            elseif verbosity > none
                @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))"
            end
        end
    end
end

const cache = Set{UInt}()

signature((@nospecialize f), (@nospecialize types)) =
    string(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

"""
    Verbosity

an `enum` that determines what logging statements are shown during [`speculate`](@ref).

In increasing verbosity, the variants are
[`none`](@ref), [`warn`](@ref), and [`debug`](@ref).

```jldoctest
julia> Verbosity
Enum Verbosity:
none = 0
warn = 1
debug = 2
```
"""
@enum Verbosity none warn debug

@doc """
    none

A variant of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show no logging statements.

# Examples

```jldoctest
julia> none
none::Verbsosity = 0
```
""" none

@doc """
    warn

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity = 1
```
""" warn

@doc """
    debug

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref) should show
each successful call to `precompile` and warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity = 2
```
""" debug

@eval function _speculate(x::DataType; verbosity, kwargs...)
    $__speculate

    for subtype in subtypes(x)
        speculate(subtype; verbosity, kwargs...)
    end
end
@eval _speculate(@nospecialize x::Function; verbosity, kwargs...) = $__speculate
_speculate(x::Module; all, kwargs...) =
    for name in names(x; all)
        isdefined(x, name) && speculate(getfield(x, name); all, kwargs...)
    end
_speculate(::Type; _...) = nothing
_speculate(x::Union; kwargs...) = for type in uniontypes(x)
    speculate(type; kwargs...)
end
_speculate(@nospecialize ::T; kwargs...) where T = speculate(T; kwargs...)

"""
    speculate(::Any; all::Bool = true, verbosity::Verbosity = warn)

If this function is used as a precompilation workload,
its `verbosity` should be set to [`none`](@ref) or [`warn`](@ref).
"""
function speculate(@nospecialize x; all::Bool = true, verbosity::Verbosity = warn)
    object_id = objectid(x)

    if !(object_id in cache)
        push!(cache, object_id)
        _speculate(x; all, verbosity)
    end
end

speculate(Speculator)

end # Speculator
