
function log_warn(p::Parameters, caller_type::Type, (@nospecialize compilable_types))
    if warn ⊆ p.verbosity
        _signature = signature(caller_type, compilable_types)
        p.counters[warned] += 1

        log_background_repl(() -> (
            @warn "Compilation failed, please file a bug report in Speculator.jl for:\n`$_signature`"
        ), p)
    end
end

function compile_methods((@nospecialize x), p::Parameters, m::Method, sig::DataType)
    if !(parentmodule(m) == Core && Tuple <: sig)
        parameter_types = sig.types[2:end]

        if isempty(parameter_types) || !isvarargtype(last(parameter_types))
            count = 1
            skip = false
            limit = p.limit
            no_specialize = m.nospecialize
            product_cache = p.product_cache
            product_types = Vector{Type}[]

            for i in eachindex(parameter_types)
                parameter_type = parameter_types[i]
                compilable_types = begin
                    if is_subset(1, no_specialize >> (i - 1)) Type[parameter_type]
                    else
                        new_compilable_types, skip = get!(product_cache, parameter_type) do
                            abstract_types = Type[parameter_type]
                            new_skip = false
                            new_compilable_types = Type[]

                            while !isempty(abstract_types)
                                branch = pop!(abstract_types)

                                if isconcretetype(branch)
                                    push!(new_compilable_types, branch)
                                    new_skip = new_skip || length(new_compilable_types) > limit
                                    new_skip && break
                                else subtypes!(abstract_types, branch, p)
                                end
                            end

                            new_compilable_types => new_skip || isempty(new_compilable_types)
                        end

                        skip = skip || begin
                            count, overflow = mul_with_overflow(
                                count, length(new_compilable_types)
                            )
                            overflow || count > limit
                        end
                        skip ? break : new_compilable_types
                    end
                end

                push!(product_types, compilable_types)
            end

            if !skip
                caller_type = Typeof(x)
                dry, generate = p.dry, p.generate

                if !(dry || generate)
                    specialization_types = IdSet{Type}()

                    for specialization in specializations(m)
                        push!(specialization_types, specialization.specTypes)
                    end
                end

                for compilable_types in product(product_types...)
                    if dry log_debug(p, generated, caller_type, compilable_types)
                    else
                        signature_type = Tuple{caller_type, compilable_types...}
                        p.counters[generated] += 1

                        if generate
                            if precompile(signature_type)
                                log_debug(p, compiled, caller_type, compilable_types)
                                println(p.file, "precompile(", signature_type, ')')
                            else log_warn(p, caller_type, compilable_types)
                            end
                        elseif any(==(signature_type), specialization_types)
                            log_debug(p, skipped, caller_type, compilable_types)
                        elseif precompile(signature_type)
                            log_debug(p, compiled, caller_type, compilable_types)
                        else log_warn(p, caller_type, compilable_types)
                        end
                    end
                end
            end
        end
    end
end
compile_methods((@nospecialize x), ::Parameters, ::Method, ::UnionAll) = nothing

search(x::Module, p::Parameters) = for name in unsorted_names(x; all = true)
    if isdefined(x, name) && p.predicate(x, name)
        searched = p.searched
        _x = getproperty(x, name)

        if _x ∉ searched
            push!(searched, _x)
            search(_x, p)
        end
    end
end
search((@nospecialize x), p::Parameters) = for method in methods(x)
    p.counters[generic] += 1
    compile_methods(x, p, method, method.sig)
end

log_review((@nospecialize x), p::Parameters) = log_foreground_repl(p) do
    elapsed = @elapsed search(x, p)

    if review ⊆ p.verbosity
        log_background_repl(p) do
            counters = p.counters
            _generated = counters[generated]
            _generic = counters[generic]
            seconds = round_time(elapsed)
            header = "Generated `$_generated` methods from `$_generic` generic methods in `$seconds` seconds"

            if p.dry @info "$header"
            else
                _compiled, _skipped, _warned = map(
                    s -> counters[s], [compiled, skipped, warned]
                )
                @info "$header\nCompiled `$_compiled`\nSkipped  `$_skipped`\nWarned   `$_warned`"
            end
        end
    end
end

function initialize_parameters(
    (@nospecialize x),
    background::Bool,
    dry::Bool,
    generate::Bool,
    is_interactive::Bool,
    limit::Int,
    path::String,
    (@nospecialize predicate),
    verbosity::Verbosity
)
    open(generate ? path : tempname(); write = true) do file
        parameters = Parameters(
            Dict(map(o -> o => 0, [compiled, generated, generic, skipped, warned])),
            dry,
            file,
            generate,
            background,
            is_interactive && isdefined(Base, :active_repl),
            limit,
            predicate,
            IdDict{Type, Pair{Vector{Type}, Bool}}(),
            IdSet{Any}(),
            IdDict{DataType, Vector{Any}}(),
            IdDict{Union, Vector{Any}}(),
            verbosity,
        )

        background ? errormonitor(@spawn log_review(x, parameters)) : log_review(x, parameters)
        nothing
    end
end


"""
    speculate(predicate, value; parameters...)
    speculate(value; parameters...)

Generate a compilation a workload.

To run a workload automatically in the REPL, see also [`install_speculator`](@ref).
To measure the duration of compilation in a workload, see also [`SpeculationBenchmarks`](@ref).

!!! tip
    Use this in a package to reduce latency for its users.

!!! note
    This function only runs when called during precompilation or an interactive session,
    or when writing precompilation directives to a file.

# Parameters

- `predicate = Returns(true)`:
    This must accept the signature `predicate(::Module,\u00A0::Symbol)::Bool`.
    Returning `true` specifies to search `getproperty(::Module,\u00A0::Symbol)`,
    whereas returning `false` specifies to ignore the value.
    The default predicate `Returns(true)` will search every possible method,
    up to its generic `limit`, whereas the predicate `Returns(false)` will
    only search for methods of values passed directly to `speculate`.
    Some useful predicates include `Base.isexported`, `Base.ispublic`,
    checking properties of the value itself, and a combination thereof.
- `value`:
    When given a `Module`, `speculate` will recursively search its
    contents using `names(::Module;\u00A0all\u00A0=\u00A0true)`,
    for each name the satisifes the `predicate`.
    For other values, each of their generic `methods`
    are searched for corresponding compilable signatures.

# Keyword parameters

- `background::Bool = false`:
    Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `dry::Bool = false`:
    Specifies whether to run `precompile` on generated method signatures.
    This is useful for testing workloads with `verbosity\u00A0=\u00A0debug\u00A0|\u00A0review`.
    Methods that are known to be specialized are skipped.
    Note that `dry` must be `false` to save the workload to a file with the `path` parameter.
- `limit::Int = $default_limit`:
    Specifies the maximum number of compilable methods that are generated from a generic method.
    Values less than `1` will throw an error.
    Otherwise, method signatures will be generated from the Cartesian product each parameter type.
    Types marked with `@nospecialize` are used directly.
    Otherwise, compilable types are obtained from the subtypes of `DataType` and `Union`.
    This prevents spending too much time precompiling a single generic method.
- `path::String = ""`:
    Writes each successful precompilation directive to a file
    if the `path` is not empty and it is not a `dry` run.
    Note that these directives may require loading additional modules to run.
- `verbosity::Verbosity = warn`:
    Specifies what logging statements to show.
    If this function is used in a package as a precompilation workload,
    this should be set to [`silent`](@ref) or [`warn`](@ref).
    See also [`Verbosity`](@ref).

# Examples
```julia-repl
julia> module Showcase
           export g, h

           f() = nothing
           g(::Int) = nothing
           h(::Union{String, Symbol}) = nothing
       end;

julia> speculate(Showcase; verbosity = debug)
[ Info: Compiled `Main.Showcase.g(::Int)`
[ Info: Compiled `Main.Showcase.f()`

julia> speculate(Base.isexported, Showcase; verbosity = debug)
[ Info: Skipped `Main.Showcase.g(::Int)`

julia> speculate(Showcase.h; limit = 2, verbosity = debug)
[ Info: Compiled `Main.Showcase.h(::String)`
[ Info: Compiled `Main.Showcase.h(::Symbol)`
```
"""
function speculate(predicate, value;
    background::Bool = false,
    dry::Bool = false,
    limit::Int = default_limit,
    path::String = "",
    verbosity::Verbosity = warn
)
    @nospecialize
    limit > 0 || error("The `limit` must be greater than `0`")

    is_interactive, generate = isinteractive(), !(dry || isempty(path))

    if generate || is_interactive || (@ccall jl_generating_output()::Cint) == 1
        initialize_parameters(
            value, background, dry, generate, is_interactive, limit, path, predicate, verbosity
        )
    end
end
function speculate(x; parameters...)
    @nospecialize
    speculate(Returns(true), x; parameters...)
end
