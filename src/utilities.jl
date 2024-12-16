
const default_ignore = []

const default_maximum_methods = 2 ^ 8

const default_target = nothing

struct Parameters
    background::Bool
    counter::Ref{Int}
    dry::Bool
    file::IOStream
    ignore_callables::Set{UInt}
    ignore_types::Set{UInt}
    maximum_methods::Int
    product_cache::Dict{UInt, Vector{DataType}}
    subtype_cache::Dict{UInt, Vector{Type}}
    target::Target
    verbosity::Verbosity
end

ignore!(f, ignore, object_id, (@nospecialize x), parameters) =
    if !(object_id in ignore)
        push!(ignore, object_id)
        f(x, parameters)
    end

check_ignore!((@nospecialize x::Union{DataType, Function, Module, UnionAll, Union}), parameters) =
    ignore!(((@nospecialize _x), _parameters) -> speculate_ignored(_x, _parameters),
        parameters.ignore_types, objectid(x), x, parameters)
function check_ignore!((@nospecialize x::T), parameters) where T
    object_id = objectid(T)
    callable_objects ⊆ parameters.target && ignore!(((@nospecialize _x), _parameters) -> 
        precompile_methods(_x, _parameters), parameters.ignore_callables, object_id, x, parameters)
    ignore!(((@nospecialize _x), _parameters) -> speculate_ignored(_x, _parameters),
        parameters.ignore_types, object_id, T, parameters)
end

is_not_vararg(::typeof(Vararg)) = false
is_not_vararg(_) = true

function log_repl((@nospecialize f), background)
    if background
        sleep(0.001)
        print(stderr, "\r\33[K\33[A")
    end

    f()

    if background
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

function precompile_concrete((@nospecialize x), parameters, (@nospecialize types))
    background, verbosity = parameters.background, parameters.verbosity

    if parameters.dry
        debug ⊆ verbosity &&
            log_repl(() -> (@info "Found `$(signature(x, types))`"), background)
        parameters.counter[] += 1
    elseif precompile(x, types)
        debug ⊆ verbosity &&
            log_repl(() -> (@info "Precompiled `$(signature(x, types))`"), background)

        if generate ⊆ verbosity
            file = parameters.file

            print(file, "precompile(")
            show(file, x)
            println(file, ", ", types, ')')
        end

        parameters.counter[] += 1
    elseif warn ⊆ verbosity
        log_repl(() -> (
            @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))`"),
        background)
    end
end

precompile_methods((@nospecialize x), parameters) =
    for method in methods(x)
        precompile_method(x, parameters, method.nospecialize, method.sig)
    end

function precompile_method((@nospecialize x), parameters, nospecialize, sig::DataType)
    target = parameters.target

    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if abstract_methods ⊆ target
            if all(is_not_vararg, parameter_types)
                product_types = map(eachindex(parameter_types)) do i
                    parameter_type = parameter_types[i]
                    get!(parameters.product_cache, objectid(parameter_type)) do
                        branches, leaves = Type[parameter_type], DataType[]
                        no_specialize = (nospecialize >> (i - 1)) & 1 == 1

                        while !isempty(branches)
                            branch = pop!(branches)

                            if isconcretetype(branch) &&
                                !any(type -> type <: branch, [DataType, UnionAll, Union])
                                push!(leaves, branch)
                                no_specialize && break
                            else append!(branches, subtypes!(branch, parameters))
                            end
                        end

                        leaves
                    end
                end

                (isempty(product_types) ||
                    prod(BigInt ∘ length, product_types) ≤ parameters.maximum_methods) &&
                    for concrete_types in product(product_types...)
                        precompile_concrete(x, parameters, concrete_types)
                    end
            end
        elseif all(isconcretetype, parameter_types)
            precompile_concrete(x, parameters, (parameter_types...,))
        end

        if method_types ⊆ target
            for parameter_type in parameter_types
                check_ignore!(parameter_type, parameters)
            end
        end
    end
end
precompile_method((@nospecialize x), parameters, nospecialize, sig::UnionAll) = nothing

function round_time(x)
    whole, fraction = split(string(max(0.0, round(x; digits = 4))), '.')
    whole * '.' * rpad(fraction, 4, '0')
end

function signature(x, types)
    @nospecialize
    signature(x) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'
end
signature(@nospecialize x::Union{Function, Type}) = repr(x)
signature(@nospecialize ::T) where T = "(::" * repr(T) * ')'

speculate_ignored((@nospecialize x::Function), parameters) = precompile_methods(x, parameters)
function speculate_ignored(x::Module, parameters)
    target = parameters.target
    for name in names(x; all = all_names ⊆ target, imported = imported_names ⊆ target)
        isdefined(x, name) && name != :eval && name != :include && name != :_precompile_ && check_ignore!(getfield(x, name), parameters)
    end
end
function speculate_ignored(x::Union{DataType, UnionAll, Union}, parameters)
    precompile_methods(x, parameters)

    for type in subtypes!(x, parameters)
        check_ignore!(type, parameters)
    end
end

subtypes!(x::DataType, parameters) =
    if abstract_subtypes ⊆ parameters.target
        get!(() -> filter!(subtype -> !(x <: subtype), subtypes(x)),
            parameters.subtype_cache, objectid(x))
    else []
    end
subtypes!(x::UnionAll, parameters) =
    union_all_caches ⊆ parameters.target ? union_all_cache!([], x, parameters) : []
subtypes!(x::Union, parameters) = union_types ⊆ parameters.target ? uniontypes(x) : []

union_all_cache!(types, x::DataType, _) =
    append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, x::UnionAll, parameters) = union_all_cache!(types, x.body, parameters)
function union_all_cache!(types, x::Union, parameters)
    for type in subtypes!(x, parameters)
        union_all_cache!(types, type, parameters)
    end

    types
end
