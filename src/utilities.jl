
@enum Counter found skipped precompiled warned

struct Parameters
    background::Bool
    counters::Dict{Counter, Int}
    dry::Bool
    file::IOStream
    generate::Bool
    limit::Int
    predicate
    product_cache::IdDict{Type, Pair{Vector{Type}, Bool}}
    searched::IdSet{Any}
    subtype_cache::IdDict{DataType, Vector{Any}}
    union_type_cache::IdDict{Union, Vector{Any}}
    verbosity::Verbosity
end

const default_limit = 1

const default_predicate = Returns(true)

const default_samples = 8

is_subset(f::Union{Int, UInt8}, _f::Union{Int32, UInt8}) = f == (f & _f)

function log_debug(c::Counter, (@nospecialize x), p::Parameters, (@nospecialize types))
    p.counters[c] += 1

    if debug ⊆ p.verbosity
        _signature = signature(x, types)
        statement = uppercasefirst(string(c))

        log_repl(() -> (@info "$statement `$_signature`"), p)
    end
end

function log_repl(f, p::Parameters)
    background = p.background

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

function round_time(x::Float64)
    whole, fraction = split(string(max(0.0, round(x; digits = 4))), '.')
    whole * '.' * rpad(fraction, 4, '0')
end

function signature(x, types)
    @nospecialize
    signature(x) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'
end
signature(@nospecialize x::Union{Function, Type}) = repr(x)
signature(@nospecialize ::T) where T = "(::" * repr(T) * ')'

subtypes!(abstract_types::Vector{Type}, x::DataType, p::Parameters) = append!(abstract_types, get!(
    () -> filter!(subtype -> !(x <: subtype), subtypes(x)),
    p.subtype_cache,
    x
))
subtypes!(abstract_types::Vector{Type}, ::UnionAll, ::Parameters) = abstract_types
subtypes!(abstract_types::Vector{Type}, x::Union, p::Parameters) = append!(
    abstract_types,
    get!(() -> uniontypes(x), p.union_type_cache, x)
)
