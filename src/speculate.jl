
function precompile_method(
    (@nospecialize x),
    p::Parameters,
    _specializations::Union{Vector{DataType}, Vector{Any}},
    (@nospecialize types)
)
    if p.dry log_debug(found, x, p, types)
    else
        signature_types = Tuple{Typeof(x), types...}

        if any(==(signature_types), _specializations) log_debug(skipped, x, p, types)
        elseif precompile(signature_types)
            log_debug(precompiled, x, p, types)
            p.generate && println(p.file, "precompile(", signature_types, ')')
        elseif warn ⊆ p.verbosity
            _signature = signature(x, types)
            p.counters[warned] += 1

            log_repl(() -> (
                @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$_signature`"
            ), p)
        end
    end
end

function precompile_methods((@nospecialize x), p::Parameters, m::Method, sig::DataType)
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
                concrete_types = begin
                    if is_subset(1, no_specialize >> (i - 1)) Type[parameter_type]
                    else
                        new_concrete_types, skip = get!(product_cache, parameter_type) do
                            abstract_types = Type[parameter_type]
                            new_skip = false
                            new_concrete_types = Type[]

                            while !isempty(abstract_types)
                                branch = pop!(abstract_types)

                                if isconcretetype(branch)
                                    push!(new_concrete_types, branch)
                                    new_skip = new_skip || length(new_concrete_types) > limit
                                    new_skip && break
                                else subtypes!(abstract_types, branch, p)
                                end
                            end

                            new_concrete_types => new_skip || isempty(new_concrete_types)
                        end

                        skip = skip || begin
                            count, overflow = mul_with_overflow(count, length(new_concrete_types))
                            overflow || count > limit
                        end
                        skip ? break : new_concrete_types
                    end
                end

                push!(product_types, concrete_types)
            end

            if !skip
                _specializations = map(
                    specialization -> specialization.specTypes,
                    specializations(m)
                )

                for concrete_types in product(product_types...)
                    precompile_method(x, p, _specializations, concrete_types)
                end
            end
        end
    end
end
precompile_methods((@nospecialize x), ::Parameters, ::Method, ::UnionAll) = nothing

search(x::Module, p::Parameters) = for name in names(x; all = true)
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
    precompile_methods(x, p, method, method.sig)
end

function log_review((@nospecialize x), p::Parameters)
    elapsed = @elapsed search(x, p)

    if review ⊆ p.verbosity
        log_repl(p) do
            counters = p.counters
            dry = p.dry
            seconds = round_time(elapsed)
            values = length(p.searched)
            s = " methods from `$values` value$(values == 1 ? "" : "s") in `$seconds` seconds"

            if dry @info "Found `$(counters[found])`$s"
            else
                _precompiled, _skipped, _warned = map(
                    s -> counters[s],
                    [precompiled, skipped, warned]
                )
                @info "Precompiled `$_precompiled`, skipped `$_skipped`, and warned `$_warned`$s"
            end
        end
    end
end

"""
    speculate(predicate = $default_predicate, ::Any; parameters...)

Generate and `precompile` a workload.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.

!!! info
    This function only runs when called during precompilation or an interactive session,
    or when writing precompilation directives to a file.

# Keyword parameters

- `background::Bool = false`:
    Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `dry::Bool = false`:
    Specifies whether to actually run `precompile`.
    This is useful for testing workloads and in [`time_precompilation`](@ref).
- `limit::Integer = $default_limit`:
    Specifies the maximum number of concrete methods that are generated from a method signature.
    Values less than `1` will throw an error.
    A value equal to `1` will only use methods where
    each parameter type is either concrete or not specialized.
    Values greater than `1` will generated concrete methods from
    the Cartesian product of the subtypes of each parameter type.
    This prevents spending too much time precompiling a single generic method.
- `path::String = ""`:
    Writes each successful precompilation directive to a file
    if the `path` is not empty and it is not a `dry` run.
- `verbosity::Verbosity = warn`:
    Specifies what logging statements to show.
    If this function is used as a precompilation workload,
    this should be set to [`silent`](@ref) or [`warn`](@ref).
    See also [`Verbosity`](@ref).

# Examples
```jldoctest
julia> module Example
           export g

           f(::Int) = nothing
           g(::Union{String, Symbol}) = nothing
       end;

julia> speculate(Example; verbosity = debug)
[ Info: Precompiled `Main.Example.f(::Int64)`

julia> speculate(Base.ispublic, Example; limit = 2, verbosity = debug)
[ Info: Precompiled `Main.Example.g(::Symbol)`
[ Info: Precompiled `Main.Example.g(::String)`
```
"""
function speculate(predicate, x;
    background::Bool = false,
    dry::Bool = false,
    limit::Integer = default_limit,
    path::String = "",
    verbosity::Verbosity = warn
)
    @nospecialize
    generate = !(dry || isempty(path))
    if generate || isinteractive() || (@ccall jl_generating_output()::Cint) == 1
        limit > 0 || error("The `limit` must be greater than `0`")

        open(generate ? path : tempname(); write = true) do file
            parameters = Parameters(
                background && isinteractive(),
                Dict(map(o -> o => 0, dry ? [found] : [skipped, precompiled, warned])),
                dry,
                file,
                generate,
                limit,
                predicate,
                IdDict{Type, Pair{Vector{Type}, Bool}}(),
                IdSet{Any}(),
                IdDict{DataType, Vector{Any}}(),
                IdDict{Union, Vector{Any}}(),
                verbosity,
            )

            background ? (@spawn log_review(x, parameters)) : log_review(x, parameters)
            nothing
        end
    end
end
function speculate(x; parameters...)
    @nospecialize
    speculate(Returns(true), x; parameters...)
end
