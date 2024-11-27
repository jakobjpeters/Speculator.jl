
module Speculator

export Verbosity, debug, none, review, speculate, warn

const __speculate = quote
    for method in methods(x)
        sig = method.sig

        if !(method in cache) && isconcretetype(sig)
            types = getfield(sig, 3)[(begin + 1):end]
            push!(cache, method)

            if precompile(x, ntuple(i -> types[i], length(types)))
                v == debug && @info "Precompiled `$(signature(x, types))`"
            elseif v > none
                @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))"
            end
        end
    end
end

const cache = Set{Method}()

signature(f, types) =
    string(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

"""
    Verbosity

An `Enum` that determines what logging statements are shown during [`speculate`](@ref).

In increasing verbosity, the variants are [`none`](@ref),
[`warn`](@ref), [`summary`](@ref), and [`debug`](@ref).

```jldoctest
julia> Verbosity
Enum Verbosity:
none = 0
warn = 1
review = 2
debug = 3
```
"""
@enum Verbosity none warn review debug

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
    review

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref) should show
warnings for failed calls to [`precompile`] and the total number of methods precompiled.

# Examples

```jldoctest
julia> review
review::Verbosity = 2
```
""" review

@doc """
    debug

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show each successful call to `precompile`, warnings for failed
calls to `precompile`, and the total number of methods precompiled.

# Examples

```jldoctest
julia> debug
debug::Verbosity = 3
```
""" debug

function _speculate(ms::Vector{Module}, m::Module, recursive::Bool, ::Verbosity, x::Module)
    recursive && m != x && push!(ms, x)
    nothing
end
_speculate(_, _, _, _, @nospecialize _) = nothing

@eval _speculate(_, _, _, v::Verbosity, x::DataType) = $__speculate
@eval _speculate(_, _, _, v::Verbosity, @nospecialize x::Function) = $__speculate

"""
    speculate(modules;
        all::Bool = true,
        ignore::Vector{Symbol} = Symbol[],
        recursive::Bool = true,
        verbosity::Verbosity = warn
    )

If this function is used as a precompilation workload,
its `verbosity` should be set to [`none`](@ref) or [`warn`](@ref).
"""
function speculate(modules; all::Bool = true, ignore::Vector{Symbol} = Symbol[],
    recursive::Bool = true, verbosity::Verbosity = summary)
    _ignore = Set(ignore)
    _modules = collect(Module, modules)
    n = length(cache)

    while !isempty(_modules)
        _module = pop!(_modules)

        for name in names(_module; all)
            name in _ignore ||
                _speculate(_modules, _module, recursive, verbosity, getfield(_module, name))
        end
    end

    if verbosity > warn @info "Precompiled `$(length(cache) - n)` methods" end
end

speculate([Speculator]; verbosity = warn)

end # Speculator
