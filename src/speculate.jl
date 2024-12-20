
precompile_method((@nospecialize x), parameters, specializations, (@nospecialize types)) =
    if parameters.dry log_debug(found, x, parameters, types)
    elseif Tuple{Typeof(x), types...} in specializations log_debug(skipped, x, parameters, types)
    elseif precompile(x, types)
        log_debug(precompiled, x, parameters, types)

        if parameters.generate
            file = parameters.file

            print(file, "precompile(")
            show(file, x)
            println(file, ", ", types, ')')
        end
    elseif warn ⊆ parameters.verbosity
        _signature = signature(x, types)
        parameters.counters[warned] += 1

        log_repl(() -> (
            @warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$_signature`"
        ), parameters)
    end

precompile_methods((@nospecialize x), parameters, method, sig::DataType) =
    if !(method.module == Core && Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]
        _specializations = map(x -> x.specTypes, specializations(method))
        target = parameters.target

        if abstract_methods ⊆ target
            if !any(isvarargtype, parameter_types)
                no_specialize = method.nospecialize

                product_types = map(eachindex(parameter_types)) do i
                    parameter_type = parameter_types[i]
                    branches = Type[parameter_type]

                    if is_subset(1, no_specialize >> (i - 1)) branches
                    else
                        get!(parameters.product_cache, parameter_type) do
                            leaves = Type[]

                            while !isempty(branches)
                                branch = pop!(branches)

                                if isconcretetype(branch)
                                    any(type -> type <: branch, [DataType, UnionAll, Union]) ||
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
                    precompile_method(x, parameters, _specializations, concrete_types)
                end
            end
        elseif all(isconcretetype, parameter_types)
            precompile_method(x, parameters, _specializations, (parameter_types...,))
        end
    end
precompile_methods((@nospecialize x), _, _, ::UnionAll) = nothing

search(x::Module, parameters) = for name in names(x; all = true)
    isdefined(x, name) && check_searched(getproperty(x, name), parameters)
end
search((@nospecialize x), _) = nothing

function check_searched((@nospecialize x), parameters)
    searched = parameters.searched

    if !(x ∈ searched)
        push!(searched, x)
        search(x, parameters)

        for method in methods(x)
            precompile_methods(x, parameters, method, method.sig)
        end
    end
end

handle_input((@nospecialize x::Some), parameters) = check_searched(something(x), parameters)
handle_input(::Nothing, parameters) = for _module in loaded_modules_array()
    check_searched(_module, parameters)
end

function log_review((@nospecialize x), parameters)
    elapsed = @elapsed handle_input(x, parameters)

    if review ⊆ parameters.verbosity
        log_repl(parameters) do
            counters = parameters.counters
            dry = parameters.dry
            seconds = round_time(elapsed)
            values = length(parameters.searched)
            s = " methods from `$values` value$(values == 1 ? "" : "s") in `$seconds` seconds"

            if dry @info "Found `$(counters[found])`$s"
            else
                _precompiled, _skipped, _warned =
                    map(s -> counters[s], [precompiled, skipped, warned])
                @info "Precompiled `$_precompiled`, skipped `$_skipped`, and warned `$_warned`$s"
            end
        end
    end
end

function initialize_parameters(x;
    background::Bool = false,
    dry::Bool = false,
    ignore = default_ignore,
    maximum_methods::Integer = default_maximum_methods,
    path::String = "",
    target::Union{Target, Nothing} = default_target,
    verbosity::Union{Verbosity, Nothing} = warn
)
    @nospecialize
    generate = !(dry || isempty(path))
    open(generate ? path : tempname(); write = true) do file
        ignored = IdSet{Any}(ignore)
        parameters = Parameters(
            background && isinteractive(),
            Dict(map(o -> o => 0, dry ? [found] : [skipped, precompiled, warned])),
            dry,
            file,
            generate,
            ignored,
            maximum_methods,
            IdDict{Type, Vector{Type}}(),
            copy(ignored),
            IdDict{DataType, Vector{Type}}(),
            Speculator.target(target),
            Speculator.verbosity(verbosity),
        )
        background ? (@spawn log_review(x, parameters)) : log_review(x, parameters)
        nothing
    end
end

function speculate(x; parameters...)
    @nospecialize
    initialize_parameters(Some(x); parameters...)
end

function speculate(; parameters...)
    @nospecialize
    initialize_parameters(nothing; parameters...)
end

"""
    speculate(::Any; parameters...)
    speculate(; parameters...)

Generate and `precompile` a workload.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.

# Keyword parameters

- `background::Bool = false`:
    Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `dry::Bool = false`:
    Specifies whether to actually run `precompile`.
    This is useful for testing workloads and in [`time_precompilation`](@ref).
- `ignore = $default_ignore`: An iterable of values that will not be speculated.
- `maximum_methods::Integer = $default_maximum_methods`:
    Ignores a method with an abstract type signature if `abstract_methods` is a
    subset of `target` and the number of concrete methods is greater than this value.
    This prevents spending too much time precompiling a single generic method,
    but is slower than manually including that function in `ignore`.
- `path::String = ""`:
    Writes each successful precompilation directive to a file
    if the `path` is not empty and it is not a `dry` run.
- `target::Union{Target, Nothing} = $default_target`:
    Specifies what methods to precompile. See also [`Target`](@ref).
- `verbosity::Union{Verbosity, Nothing} = warn`:
    Specifies what logging statements to show.
    If this function is used as a precompilation workload,
    this should be set to `nothing` or [`warn`](@ref).
    See also [`Verbosity`](@ref).

# Examples
```jldoctest
julia> module Example
           export g

           f(::Int) = nothing
           g(::Union{String, Symbol}) = nothing
       end;

julia> speculate(Example;
           target = all_names,
           verbosity = debug
       )
[ Info: Precompiled `Main.Example.f(::Int64)`

julia> speculate(Example;
           target = abstract_methods | union_types,
           verbosity = debug
       )
[ Info: Precompiled `Main.Example.g(::Symbol)`
[ Info: Precompiled `Main.Example.g(::String)`
```
"""
speculate
