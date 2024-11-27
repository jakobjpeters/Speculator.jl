
module Speculator

using Base: Iterators.product

export speculate

const cache = Set()

is_vararg(::typeof(Vararg)) = true
is_vararg(_) = false

function speculate(modules::Vector{Module}; all = true, recursive = true)
    functions = []
    types = []

    while !isempty(modules)
        _module = pop!(modules)
        _names = names(_module; all)

        for name in _names
            x = getfield(_module, name)
            is_type = x isa DataType

            recursive && x isa Module && x != _module && push!(modules, x)
            (is_type || x isa Function) && push!(functions, x => methods(x))
            if is_type
                super_types = Set{Type}()
                push!(types, x => super_types)

                while !(Any <: x)
                    push!(super_types, x)
                    x = supertype(x)
                end
            end
        end
    end

    for ((type, super_types), (_function, sigs)) in product(types,
        Iterators.map(((_function, methods),) -> _function => Iterators.filter(
    isconcretetype, Iterators.map(method -> method.sig, methods)), functions))
        in_super_types = in(super_types)

        for sig in sigs
            parameter_types = getfield(sig, 3)[(begin + 1):end]
            concrete_types = ntuple(length(parameter_types)) do i
                parameter_type = parameter_types[i]
                in_super_types(parameter_type) ? type : parameter_type
            end
            signature = _function => concrete_types

            if !in(signature, cache)
                push!(cache, signature)
                if !precompile(_function, concrete_types)
                    s = join(map(concrete_type -> "::" * string(concrete_type), concrete_types), ", ")
                    @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$_function($s)`"
                end
                concrete_types
            end
        end
    end
end

speculate([Speculator])

end # Speculator
