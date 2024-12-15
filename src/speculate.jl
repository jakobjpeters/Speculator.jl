
function _speculate((@nospecialize x), parameters)
    elapsed = @elapsed check_ignore!(x, parameters)

    if review ⊆ parameters.verbosity
        counter = parameters.counter[]
        seconds = round_time(elapsed)
        statement = parameters.dry ? "Found" : "Precompiled"
        values = sum(length, [parameters.ignore_callables, parameters.ignore_types])
        log_repl(() -> (
            @info "$statement `$counter` methods from `$values` values in `$seconds` seconds"),
        parameters.background)
    end
end

"""
    speculate(::Any;
        background::Bool = true,
        dry::Bool = false,
        ignore = $default_ignore,
        maximum_methods::Integer = $default_maximum_methods,
        target::Union{Target, Nothing} = $default_target,
        verbosity::Union{Verbosity, Nothing} = warn
    )

Generate and `precompile` a workload from the given value.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.

# Keyword parameters

- `background`:
    Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `dry`:
    Specifies whether to actually run `precompile`.
    This is useful for [`time_precompilation`](@ref).
- `ignore`: An iterable of values that will not be speculated.
- `maximum_methods`:
    Ignores a method with an abstract type signature if `abstract_methods` is a subset
    of the `target` and the number of concrete methods is greater than this value.
    This prevents spending too much time precompiling a single generic method,
    but is slower than manually including that function in `ignore`.
- `target`: Specifies what methods to precompile. See also [`Target`](@ref).
- `verbosity`:
    Specifies what logging statements to show.
    If this function is used as a precompilation workload,
    this should be set to `nothing` or [`warn`](@ref).
    See also [`Verbosity`](@ref).

# Examples
```jldoctest
julia> speculate(Speculator)
```
"""
function speculate((@nospecialize x);
    background::Bool = true,
    dry::Bool = false,
    ignore = default_ignore,
    maximum_methods::Integer = default_maximum_methods,
    target::Union{Target, Nothing} = default_target,
    verbosity::Union{Verbosity, Nothing} = warn
)
    ignore_callables = Set(map(objectid, ignore))
    parameters = Parameters(background, Ref(0), dry, ignore_callables,
        copy(ignore_callables), maximum_methods, Dict{UInt, Vector{DataType}}(),
    Dict{UInt, Vector{Type}}(), Speculator.target(target), Speculator.verbosity(verbosity))

    background ? (@spawn _speculate(x, parameters); nothing) : _speculate(x, parameters)
end
