
module Speculator

export Verbosity, debug, none, speculate, warn

const __speculate = quote
    for method in methods(x)
        sig = method.sig

        if isconcretetype(sig)
            types = getfield(sig, 3)[(begin + 1):end]

            if precompile(x, ntuple(i -> types[i], length(types)))
                v == debug && @info "Precompiled `$(signature(x, types))`"
            elseif v > none
                @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))"
            end
        end
    end
end

signature(f, types) =
    string(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

"""
    Verbosity

An `Enum` that determines what logging statements are shown during [`speculate`](@ref).

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
    recursive::Bool = true, verbosity::Verbosity = warn)
    _ignore = Set(ignore)
    _modules = collect(Module, modules)

    while !isempty(_modules)
        _module = pop!(_modules)

        for name in names(_module; all)
            name in _ignore ||
                _speculate(_modules, _module, recursive, verbosity, getfield(_module, name))
        end
    end
end

speculate([Speculator])

end # Speculator
