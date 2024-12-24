
@enum Counter compiled generated generic skipped warned

struct Parameters
    counters::Dict{Counter, Int}
    dry::Bool
    file::IOStream
    generate::Bool
    is_background::Bool
    is_repl::Bool
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

const default_trials = 8

is_subset(f::Union{Int, UInt8}, _f::Union{Int32, UInt8}) = f == (f & _f)

function log_debug(p::Parameters, c::Counter, caller_type::Type, (@nospecialize caller_types))
    p.counters[c] += 1

    if debug ⊆ p.verbosity
        _signature = signature(caller_type, caller_types)
        statement = uppercasefirst(string(c))

        log_repl(() -> (@info "$statement `$_signature`"), p)
    end
end

function log_repl(f, p::Parameters)
    (is_background_repl = p.is_background && p.is_repl) && print(stderr, "\r\33[K")
    f()
    if is_background_repl
        println(stderr, "\33[A")
        refresh_line(Base.active_repl.mistate)
    end
end

function round_time(x::Float64)
    whole, fraction = split(string(max(0.0, round(x; digits = 4))), '.')
    whole * '.' * rpad(fraction, 4, '0')
end

function signature(caller_type::Type, @nospecialize compilable_types)
    @nospecialize
    s = join(map(type -> "::" * string(type), compilable_types), ", ")
    signature(caller_type) * '(' * s * ')'
end
function signature(caller_type::DataType)
    if isdefined(caller_type, :instance) repr(caller_type.instance)
    else
        parameters = caller_type.parameters
        isempty(parameters) ? "(::" * repr(caller_type) * ')' : repr(only(parameters))
    end
end
signature(caller_type::UnionAll) = "(::" * repr(caller_type) * ')'
signature(caller_type::Union{Union, TypeofBottom}) = repr(caller_type)

subtypes!(abstract_types::Vector{Type}, x::DataType, p::Parameters) = append!(abstract_types, get!(
    () -> filter!(subtype -> !(x <: subtype), subtypes(x)), p.subtype_cache, x
))
subtypes!(abstract_types::Vector{Type}, ::UnionAll, ::Parameters) = abstract_types
subtypes!(abstract_types::Vector{Type}, x::Union, p::Parameters) = append!(
    abstract_types, get!(() -> uniontypes(x), p.union_type_cache, x)
)
