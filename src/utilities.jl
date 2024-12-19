
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
    ignored::IdSet{Any}
    maximum_methods::Int
    product_cache::IdDict{Type, Vector{Type}}
    searched::IdSet{Any}
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

function log_debug(counter, (@nospecialize x), parameters, (@nospecialize types))
    parameters.counters[counter] += 1

    if debug ⊆ parameters.verbosity
        _signature = signature(x, types)
        statement = uppercasefirst(string(counter))

        log_repl(() -> (@info "$statement `$_signature`"), parameters)
    end
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
        refresh_line(Base.active_repl.mistate)
    end
end

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
    union_all_types ⊆ parameters.target ? union_all_cache!([], x, parameters) : []
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
