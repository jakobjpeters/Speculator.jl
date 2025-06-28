
const verbosities = reverse(tail(instances(Verbosity)))
const default_limit = 1
const default_predicate = Returns(true)
const searched_callables = IdSet{DataType}
const searched_functions = IdSet{Function}
const searched_types = IdSet{Type}

@kwdef struct Parameters
    background_repl::Bool
    compile::Bool
    file::IOStream
    limit::Int
    predicate
    verbosity::Verbosity
    counters::Dict{Verbosity, Int} = Dict(verbosities .=> 0)
    predicate_cache::IdDict{Pair{Module, Symbol}, Bool} = IdDict{Pair{Module, Symbol}, Bool}()
    product_cache::IdDict{Type, Pair{Vector{Type}, Bool}} = IdDict{
        DataType, Pair{Vector{Type}, Bool}
    }()
    searched_callables::searched_callables = searched_callables()
    searched_functions::searched_functions = searched_functions()
    searched_methods::IdSet{Method} = IdSet{Method}()
    searched_types::searched_types = searched_types()
    subtype_cache::IdDict{DataType, Vector{Any}} = IdDict{DataType, Vector{Any}}()
    union_type_cache::IdDict{Union, Vector{Any}} = IdDict{Union, Vector{Any}}()
end

is_repl_ready() = (
    isdefined(Base, :active_repl_backend) &&
    isdefined(Base, :active_repl) &&
    !isnothing(Base.active_repl_backend)
) && begin
    active_repl = Base.active_repl
    !(isnothing(active_repl) || isnothing(active_repl.mistate))
end

is_subset(f::Integer, _f::Integer) = f == (f & _f)

function log_repl(
    p::Parameters, verbosity::Verbosity, caller_type::Type, caller_types::Vector{Type}
)
    p.counters[verbosity] += 1

    if verbosity ⊆ p.verbosity
        log_repl(p.background_repl) do
            name, color = details(verbosity)

            printstyled(name, ": "; color)
            show_signature(caller_type, caller_types)
        end
    end
end

function log_repl(messager, background_repl::Bool)
    if background_repl
        active_repl = Base.active_repl
        refresh_line = typeof(active_repl).name.module.LineEdit.refresh_line
        mistate = active_repl.mistate

        sleep(0.01)
        invokelatest(refresh_line, mistate)
        print(stderr, "\r\33[K")
    end

    messager()
    background_repl && invokelatest(refresh_line, mistate)
    nothing
end

function show_signature(caller_type::Type, compilable_types::Vector{Type})
    _compilable_types = Stateful(compilable_types)

    show_signature(caller_type)
    print('(')

    for compilable_type ∈ _compilable_types
        print("::")
        show(compilable_type)
        isempty(_compilable_types) || print(", ")
    end

    println(')')
end
function show_signature(caller_type::DataType)
    if isdefined(caller_type, :instance) show(caller_type.instance)
    elseif hasproperty(caller_type, :name)
        name = caller_type.name

        if hasproperty(name, :name) && name.module == Core && name.name == :Type
            show(only(caller_type.parameters))
        else show(caller_type)
        end
    else show(caller_type)
    end
end
function show_signature(caller_type::UnionAll)
    var = caller_type.var

    if var.lb <: Union{} && Any <: var.ub show(caller_type)
    else
        print('(')
        show(caller_type)
        print(')')
    end
end
show_signature(caller_type::Union{TypeofBottom, Union}) = show(caller_type)

function _subtypes!(
    f,
    abstract_types::Vector{Type},
    type::Union{DataType, Union},
    cache,
    p::Parameters
)
    append!(abstract_types, get!(
        () -> filter!(subtype -> check_predicate(subtype, p), f()), cache, type
    ))
end

subtypes!(abstract_types::Vector{Type}, type::DataType, p::Parameters) = _subtypes!(
    () -> filter!(subtype -> !(type <: subtype), subtypes(type)),
    abstract_types,
    type,
    p.subtype_cache,
    p
)
subtypes!(abstract_types::Vector{Type}, ::UnionAll, ::Parameters) = abstract_types
subtypes!(abstract_types::Vector{Type}, type::Union, p::Parameters) = _subtypes!(
    () -> uniontypes(type), abstract_types, type, p.union_type_cache, p
)

function wait_for_repl()
    _time = time()
    while !(repl_ready = is_repl_ready()) && time() - _time < 10 sleep(0.1) end
    repl_ready ? nothing : error("Timed out waiting for REPL to load")
end
