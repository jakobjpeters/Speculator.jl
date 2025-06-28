
compile_methods((@nospecialize x::Builtin), ::Parameters, ::Method, ::DataType) = nothing
function compile_methods((@nospecialize x), p::Parameters, m::Method, sig::DataType)
    parameter_types = sig.types[2:end]

    if isempty(parameter_types) || !isvarargtype(last(parameter_types))
        count = 1
        skip = false
        limit = p.limit
        no_specialize = m.nospecialize
        product_cache = p.product_cache
        product_types = Vector{Type}[]

        for i ∈ eachindex(parameter_types)
            parameter_type = parameter_types[i]
            compilable_types = begin
                if isconcretetype(parameter_type) || is_subset(1, no_specialize >> (i - 1))
                    if check_predicate(parameter_type, p) Type[parameter_type]
                    else (skip = true) && break
                    end
                else
                    new_compilable_types, skip = get!(product_cache, parameter_type) do
                        abstract_types = Type[parameter_type]
                        new_skip = false
                        new_compilable_types = Type[]

                        while !isempty(abstract_types)
                            branch = pop!(abstract_types)

                            if isconcretetype(branch)
                                if check_predicate(branch, p)
                                    push!(new_compilable_types, branch)
                                    (new_skip = length(new_compilable_types) > limit) && break
                                end
                            else subtypes!(abstract_types, branch, p)
                            end
                        end

                        new_compilable_types => new_skip || isempty(new_compilable_types)
                    end

                    skip = skip || begin
                        count, overflow = mul_with_overflow(count, length(new_compilable_types))
                        overflow || count > limit
                    end
                    skip ? break : new_compilable_types
                end
            end

            push!(product_types, compilable_types)
        end

        if !skip
            caller_type = Typeof(x)
            compile = p.compile

            if compile
                file = p.file
                _open = isopen(file)
                specialization_types = IdSet{Type}()

                for specialization ∈ specializations(m)
                    push!(specialization_types, specialization.specTypes)
                end
            end

            for compilable_types ∈ CartesianProduct(product_types)
                signature_type = Tuple{caller_type, compilable_types...}

                if !compile || any(==(signature_type), specialization_types)
                    log_repl(p, pass, caller_type, compilable_types)
                elseif precompile(signature_type)
                    log_repl(p, Speculator.compile, caller_type, compilable_types)
                    if _open println(file, "precompile(", signature_type, ')') end
                else log_repl(p, warn, caller_type, compilable_types)
                end
            end
        end
    end
end
compile_methods((@nospecialize x), ::Parameters, ::Method, ::UnionAll) = nothing

check_module(x::Module, m::Module) = x != parentmodule(x) == m
check_module((@nospecialize x), ::Module) = true

_check_searched((@nospecialize x), searched::Union{
    searched_callables, searched_functions, searched_types
}) = x ∉ searched && (push!(searched, x); true)

function check_searched((@nospecialize x::Function), p::Parameters)
    F = typeof(x)

    if issingletontype(F) _check_searched(x, p.searched_functions)
    else _check_searched(F, p.searched_callables)
    end
end
check_searched(x::Type, p::Parameters) = _check_searched(x, p.searched_types)
check_searched((@nospecialize x), p::Parameters) = _check_searched(typeof(x), p.searched_callables)

check_predicate(x::Module, name::Symbol, p::Parameters) = get!(
    () -> p.predicate(x, name), p.predicate_cache, x => name
)
function check_predicate(x::DataType, p::Parameters)
    type_name = typename(x)
    check_predicate(type_name.module, type_name.name, p)
end
check_predicate(x::UnionAll, p::Parameters) = check_predicate(unwrap_unionall(x), p)
check_predicate(x::Union, p::Parameters) = any(type -> check_predicate(type, p), uniontypes(x))

search(x::Module, p::Parameters) = for name ∈ unsorted_names(x; all = true)
    if (
        isdefined(x, name) &&
        !isdeprecated(x, name) &&
        check_predicate(x, name, p)
    )
        _x = getproperty(x, name)
        check_module(_x, x) && search(_x, p)
    end
end
search((@nospecialize x), p::Parameters) = if check_searched(x, p)
    for method ∈ methods(x)
        if method ∉ p.searched_methods
            push!(p.searched_methods, method)
            p.counters[review] += 1
            compile_methods(x, p, method, method.sig)
        end
    end
end

search_all_modules(::AllModules, p::Parameters) = for _module ∈ loaded_modules_array()
    search(_module, p)
end
search_all_modules((@nospecialize x), p::Parameters) = search(x, p)

function initialize_parameters(
    (@nospecialize x), path::String, save::Bool; (@nospecialize parameters...)
)
    open(save ? path : tempname(); write = true) do file
        save || close(file)
        _parameters = Parameters(; file, parameters...)
        elapsed = @elapsed search_all_modules(x, _parameters)

        if review ⊆ _parameters.verbosity
            counters = _parameters.counters
            warned, reviewed, passed, compiled = map(verbosity -> counters[verbosity], verbosities)
            generated = compiled + passed + warned
            seconds = round_time(elapsed)
            name, color = details(review)

            log_repl(_parameters.background_repl) do
                printstyled(name, ": "; color)
                println(
                    "Generated $generated compilable signatures from $reviewed methods in $seconds seconds"
                )

                if _parameters.compile
                    for (verbosity, counter) ∈ (
                        compile => compiled, pass => passed, warn => warned
                    )
                        _name, _color = details(verbosity)

                        printstyled("- "; color)
                        printstyled(_name, ": "; color = _color)
                        println(counter)
                    end
                end
            end
        end
    end
end

"""
    speculate(predicate, value; parameters...)
    speculate(value; parameters...)

Search for compilable methods.

See also [`install_speculator`](@ref).

!!! tip
    Use this in a package to reduce latency.

!!! note
    This only runs when called during precompilation or an interactive session,
    or when writing precompilation directives to a file.

# Parameters

- `predicate = Returns(true)`:
    This must accept the signature `predicate(::Module,\u00A0::Symbol)::Bool`.
    Returning `true` specifies to search `getproperty(::Module,\u00A0::Symbol)`,
    whereas returning `false` specifies to skip the value.
    This is called when searching the names of a `Module` if the
    given module and name satisfy `isdefined` and `!isdeprecated`,
    and is called when searching for types from method parameters.
    Each component of a `Union` type is checked individually.
    Skipped parameter types do not count towards the method specialization `limit`.
    The default predicate `Returns(true)` will search every value,
    whereas the predicate `Returns(false)` will not search any value.
    Some useful predicates include `Base.isexported`,
    `Base.ispublic`, and checking properties of the value itself.
- `value`:
    When given a `Module`, `speculate` will recursively search its contents
    using `names(::Module;\u00A0all\u00A0=\u00A0true)`, for each defined value that
    is not deprecated, is not an external module, and satisifes the `predicate`.
    For other values, each of their generic `methods`
    are searched for corresponding compilable methods.

# Keyword parameters

- `background::Bool = false`:
    Specifies whether to run on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `compile::Bool = true`:
    Specifies whether to run `precompile` on generated method signatures.
    Skipping compilation is useful for testing with
    `verbosity\u00A0=\u00A0debug\u00A0∪\u00A0review`.
    Method signatures that are known to be specialized are skipped.
    Note that `compile` must be `true` to save the directives to a file with the `path` parameter.
- `limit::Int = $default_limit`:
    Specifies the maximum number of concrete method
    signatures that are generated from a generic method.
    Values less than `1` will throw an error.
    Otherwise, method signatures will be generated from the Cartesian product each parameter type.
    Concrete types and those marked with `@nospecialize` are used directly.
    Otherwise, concrete types are obtained from the subtypes of `DataType` and `Union`.
    Setting an appropriate value prevents spending too
    much time precompiling a single generic method.
- `path::String = ""`:
    Saves successful precompilation directives to a file
    if `compile = true` and `!isempty(path)`.
    Generated method signatures that are known to have been compiled are skipped.
    The resulting directives may require loading additional modules to run.
    [CompileTraces.jl](https://github.com/serenity4/CompileTraces.jl)
    may be useful in such cases.
- `verbosity::Verbosity = warn`:
    Specifies what logging statements to show.
    If this function is used to precompile a package,
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

julia> speculate(Showcase.h; verbosity = debug) do m, n
           !(m == Core && n == :String)
       end
[ Info: Compiled `Main.Showcase.h(::Symbol)`

julia> speculate(Showcase.h; limit = 2, verbosity = debug)
[ Info: Skipped `Main.Showcase.h(::String)`
[ Info: Compiled `Main.Showcase.h(::Symbol)`
```
"""
function speculate(predicate, value;
    background::Bool = false,
    compile::Bool = true,
    limit::Int = default_limit,
    path::String = "",
    verbosity::Verbosity = warn
)
    @nospecialize
    limit > 0 || error("the `limit` must be greater than `0`")
    interactive, save = isinteractive(), compile && !isempty(path)

    if interactive || save || (@ccall jl_generating_output()::Cint) == 1
        if background
            errormonitor(@spawn begin
                (background_repl = interactive && verbosity != silent) && wait_for_repl()
                initialize_parameters(
                    value, path, save; background_repl, compile, limit, predicate, verbosity
                )
            end)
            nothing
        else
            initialize_parameters(
                value, path, save; compile, limit, predicate, verbosity, background_repl = false
            )
        end
    end
end
function speculate(x; parameters...)
    @nospecialize
    speculate(Returns(true), x; parameters...)
end
