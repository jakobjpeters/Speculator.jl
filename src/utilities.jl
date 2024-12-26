
@enum Counter compiled generic skipped warned

const counters = instances(Counter)

const searched_callables = IdSet{DataType}

const searched_functions = IdSet{Function}

const searched_types = IdSet{Type}

@kwdef struct Parameters
    background_repl::Bool
    dry::Bool
    file::IOStream
    limit::Int
    predicate
    verbosity::Verbosity
    counters::Dict{Counter, Int} = Dict(map(o -> o => 0, counters))
    predicate_cache::IdDict{Pair{Module, Symbol}, Bool} = IdDict{Pair{Module, Symbol}, Bool}()
    product_cache::IdDict{Type, Pair{Vector{Type}, Bool}} = IdDict{DataType, Pair{Vector{Type}, Bool}}()
    searched_callables::searched_callables = searched_callables()
    searched_functions::searched_functions = searched_functions()
    searched_types::searched_types = searched_types()
    subtype_cache::IdDict{DataType, Vector{Any}} = IdDict{DataType, Vector{Any}}()
    union_type_cache::IdDict{Union, Vector{Any}} = IdDict{Union, Vector{Any}}()

    searched_methods::IdSet{Method} = IdSet{Method}()
end

const default_limit = 1

const default_predicate = Returns(true)

const default_trials = 8

is_repl_ready() = (
    isdefined(Base, :active_repl_backend) &&
    isdefined(Base, :active_repl) &&
    !isnothing(Base.active_repl_backend)
) && begin
    active_repl = Base.active_repl
    !(isnothing(active_repl) || isnothing(active_repl.mistate))
end

is_subset(f::Union{Int, UInt8}, _f::Union{Int32, UInt8}) = f == (f & _f)

function log_debug(p::Parameters, c::Counter, caller_type::Type, (@nospecialize caller_types))
    p.counters[c] += 1

    if debug ⊆ p.verbosity
        _signature = signature(caller_type, caller_types)
        statement = uppercasefirst(string(c))

        log_background_repl(() -> (@info "$statement `$_signature`"), p.background_repl)
    end
end

function log_background_repl(f, background_repl::Bool)
    if background_repl
        active_repl = Base.active_repl
        refresh_line = typeof(active_repl).name.module.LineEdit.refresh_line
        mistate = active_repl.mistate

        sleep(0.01)
        refresh_line(mistate)
        print(stderr, "\r\33[K")
    end

    f()

    background_repl && refresh_line(mistate)
    nothing
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

function wait_for_repl()
    _time = time()

    while !(repl_ready = is_repl_ready()) && time() - _time < 10
        sleep(0.1)
    end

    repl_ready ? nothing : error("Timed out waiting for REPL to load")
end
