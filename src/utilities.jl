
@enum Counter compiled generic skipped warned

const counters = instances(Counter)

@kwdef struct Parameters
    file::IOStream
    is_background::Bool
    is_dry::Bool
    is_repl::Bool
    limit::Int
    predicate
    verbosity::Verbosity
    counters::Dict{Counter, Int} = Dict(map(o -> o => 0, counters))
    product_cache::IdDict{Type, Pair{Vector{Type}, Bool}} = IdDict{DataType, Pair{Vector{Type}, Bool}}()
    searched::IdSet{Any} = IdSet{Any}()
    subtype_cache::IdDict{DataType, Vector{Any}} = IdDict{DataType, Vector{Any}}()
    union_type_cache::IdDict{Union, Vector{Any}} = IdDict{Union, Vector{Any}}()
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

        log_background_repl(() -> (@info "$statement `$_signature`"), p)
    end
end

function log_background_repl(f, is_background_repl::Bool)
    if is_background_repl
        sleep(0.01)
        print(stderr, "\r\33[K")
    end

    f()

    if is_background_repl
        active_repl = Base.active_repl
        println(stderr, "\33[A")
        typeof(active_repl).name.module.LineEdit.refresh_line(active_repl.mistate)
    end
end
log_background_repl(f, p::Parameters) = log_background_repl(f, p.is_background && p.is_repl)

function log_foreground_repl(f, is_foreground_repl::Bool)
    is_foreground_repl && println(stderr)
    f()
    is_foreground_repl ? print(stderr, "\33[A") : nothing
end
log_foreground_repl(f, p::Parameters) = log_foreground_repl(f, !p.is_background && p.is_repl)

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
