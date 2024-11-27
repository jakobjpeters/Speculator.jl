
module Speculator

export speculate!

_speculate(modules, recursive, m, x::Module) =
    if recursive && m != x push!(modules, x) end
_speculate(_, _, _, @nospecialize x::Union{DataType, Function}) = for method in methods(x)
    sig = method.sig

    if isconcretetype(sig)
        parameter_types = getfield(sig, 3)[(begin + 1):end]
        precompile(x, ntuple(i -> parameter_types[i], length(parameter_types))) ||
            @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$x($(
        join(map(concrete_type -> "::" * string(concrete_type), parameter_types), ", ")))`"
    end
end
_speculate(_, _, _, @nospecialize _) = nothing

function speculate!(modules::Vector{Module}; all = true, recursive = true)
    while !isempty(modules)
        _module = pop!(modules)

        for name in names(_module; all)
            _speculate(modules, recursive, _module, getfield(_module, name))
        end
    end
end

speculate!([Speculator])

end # Speculator
