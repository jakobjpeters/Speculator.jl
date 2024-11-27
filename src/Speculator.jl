
module Speculator

export speculate

const cache = Set{Method}()

_speculate(modules::Vector{Module}, recursive::Bool, _module::Module, x::Module) =
    if recursive && _module != x push!(modules, x) end
_speculate(_, _, _, @nospecialize x::Union{DataType, Function}) = for method in methods(x)
    sig = method.sig

    if !(method in cache) && isconcretetype(sig)
        push!(cache, method)
        parameter_types = getfield(sig, 3)[(begin + 1):end]
        precompile(x, ntuple(i -> parameter_types[i], length(parameter_types))) ||
            @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$x($(
        join(map(concrete_type -> "::" * string(concrete_type), parameter_types), ", ")))`"
    end
end
_speculate(_, _, _, @nospecialize _) = nothing

"""
    speculate(modules;
        all::Bool = true,
        ignore::Vector{Symbol} = Symbol[],
        log::Bool = true
    )
"""
function speculate(modules;
    all::Bool = true, ignore::Vector{Symbol} = Symbol[], log::Bool = true, recursive::Bool = true)
    _ignore = Set(ignore)
    _modules = collect(Module, modules)
    n = length(cache)

    while !isempty(_modules)
        _module = pop!(_modules)

        for name in names(_module; all)
            name in _ignore || _speculate(_modules, recursive, _module, getfield(_module, name))
        end
    end

    log && @info "Precompiled `$(length(cache) - n)` methods"
end

speculate([Speculator])

end # Speculator
