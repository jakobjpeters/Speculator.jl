
const default_maximum_methods = 1

const default_predicate = Returns(true)

@enum Counter found skipped precompiled warned

struct Parameters{T}
    background::Bool
    counters::Dict{Counter, Int}
    dry::Bool
    file::IOStream
    generate::Bool
    maximum_methods::Int
    predicate::T
    product_cache::IdDict{Type, Pair{Vector{Type}, Bool}}
    searched::IdSet{Any}
    subtype_cache::IdDict{DataType, Vector{Any}}
    union_type_cache::IdDict{Union, Vector{Any}}
    verbosity::Verbosity
end

is_subset(f, _f) = f == (f & _f)

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

subtypes!(branches, x::DataType, parameters) =
    if parameters.predicate(x)
        append!(branches, get!(() -> filter!(subtype -> !(x <: subtype), subtypes(x)),
            parameters.subtype_cache, x))
    else branches
    end
subtypes!(branches, ::UnionAll, _) = branches
subtypes!(branches, x::Union, parameters) = parameters.predicate(x) ?
    append!(branches, get!(() -> uniontypes(x), parameters.union_type_cache, x)) : branches
