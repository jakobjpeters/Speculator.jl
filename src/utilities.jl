
const default_ignore = []

const default_maximum_methods = 2 ^ 8

const default_target = nothing

@enum Counter found skipped precompiled warned

struct Parameters
    background::Bool
    counters::Dict{Counter, Int}
    dry::Bool
    file::IOStream
    generate::Bool
    ignore::IdSet{Any}
    maximum_methods::Int
    product_cache::IdDict{Type, Vector{Type}}
    subtype_cache::IdDict{DataType, Vector{Type}}
    target::Target
    verbosity::Verbosity
end

function ignore!(f, (@nospecialize x), parameters)
    ignore = parameters.ignore
    if !(x in ignore)
        push!(ignore, x)
        f(x, parameters)
    end
end

is_subset(f, _f) = f == (f & _f)

check_ignore!((@nospecialize x::Union{DataType, Function, Module, UnionAll, Union}), parameters) =
    ignore!(((@nospecialize _x), _parameters) -> speculate_ignored(_x, _parameters), x, parameters)
function check_ignore!((@nospecialize x::T), parameters) where T
    callable_objects ⊆ parameters.target && ignore!(
        ((@nospecialize _x), _parameters) -> precompile_methods(_x, _parameters), x, parameters)
    ignore!(((@nospecialize _x), _parameters) -> speculate_ignored(_x, _parameters), T, parameters)
end

log_debug(statement, (@nospecialize x), parameters, (@nospecialize types)) =
    if debug ⊆ parameters.verbosity
        log_repl(() -> (@info "$statement `$(signature(x, types))`"), parameters)
    end

function log_repl((@nospecialize f), parameters)
    background = parameters.background

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

function precompile_concrete((@nospecialize x), parameters, specializations, (@nospecialize types))
    background = parameters.background
    counters = parameters.counters
    verbosity = parameters.verbosity

    if parameters.dry
        log_debug("Found", x, parameters, types)
        counters[found] += 1
    elseif Tuple{Typeof(x), types...} in specializations
        log_debug("Skipped", x, parameters, types)
        counters[skipped] += 1
    else
        background, verbosity = parameters.background, parameters.verbosity

        if precompile(x, types)
            log_debug("Precompiled", x, parameters, types)
            counters[precompiled] += 1

            if parameters.generate
                file = parameters.file

                print(file, "precompile(")
                show(file, x)
                println(file, ", ", types, ')')
            end
        elseif warn ⊆ verbosity
            log_repl(() -> (
                @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))`"
            ), parameters)
            counters[warned] += 1
        end
    end
end

precompile_methods((@nospecialize x), parameters) =
    for method in methods(x)
        precompile_method(x, parameters, method, method.sig)
    end

function precompile_method((@nospecialize x), parameters, method, sig::DataType)
    no_specialize = method.nospecialize
    _specializations = map(x -> x.specTypes, specializations(method))
    target = parameters.target

    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if abstract_methods ⊆ target
            if !any(isvarargtype, parameter_types)
                product_types = map(eachindex(parameter_types)) do i
                    parameter_type = parameter_types[i]
                    branches = Type[parameter_type]

                    if is_subset(1, no_specialize >> (i - 1)) branches
                    else
                        get!(parameters.product_cache, parameter_type) do
                            leaves = Type[]

                            while !isempty(branches)
                                branch = pop!(branches)

                                if isconcretetype(branch) &&
                                    !any(type -> type <: branch, [DataType, UnionAll, Union])
                                    push!(leaves, branch)
                                else append!(branches, subtypes!(branch, parameters))
                                end
                            end

                            leaves
                        end
                    end
                end

                isempty(product_types) || begin
                    count = 1

                    for product_type in product_types
                        count, overflow = mul_with_overflow(count, length(product_type))
                        overflow && return false
                    end

                    count ≤ parameters.maximum_methods
                end && for concrete_types in product(product_types...)
                    precompile_concrete(x, parameters, _specializations, concrete_types)
                end
            end
        elseif all(isconcretetype, parameter_types)
            precompile_concrete(x, parameters, _specializations, (parameter_types...,))
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
        isdefined(x, name) && check_ignore!(getfield(x, name), parameters)
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
        get!(() -> filter!(subtype -> !(x <: subtype), subtypes(x)), parameters.subtype_cache, x)
    else []
    end
subtypes!(x::UnionAll, parameters) =
    union_all_caches ⊆ parameters.target ? union_all_cache!([], x, parameters) : []
subtypes!(x::Union, parameters) = union_types ⊆ parameters.target ? uniontypes(x) : []

union_all_cache!(types, x::DataType, _) =
    append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, x::UnionAll, parameters) =
    union_all_cache!(types, unwrap_unionall(x), parameters)
function union_all_cache!(types, x::Union, parameters)
    for type in subtypes!(x, parameters)
        union_all_cache!(types, type, parameters)
    end

    types
end
