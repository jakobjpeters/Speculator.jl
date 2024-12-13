
"""
    speculate(::Any;
        background::Bool = true,
        dry::Bool = false,
        ignore = $default_ignore,
        max_methods::Integer = $default_max_methods,
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
    Ignores a generic method if `abstract_methods` is a subset of the
    `target` and the number of concrete methods is greater than this value.
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
function speculate(x;
    background::Bool = true,
    dry::Bool = false,
    ignore = default_ignore,
    max_methods::Integer = default_max_methods,
    target::Union{Target, Nothing} = default_target,
    verbosity::Union{Verbosity, Nothing} = warn
)
    function _speculate()
        cache, count = Set(Iterators.map(objectid, ignore)), Ref(0)
        callable_cache, _verbosity = copy(cache), Speculator.verbosity(verbosity)

        elapsed = round_time(@elapsed check_cache(x;
            all_names, background, cache, callable_cache, count, dry, imported_names, max_methods,
        target = Speculator.target(target), verbosity = _verbosity))

        if review ⊆ _verbosity
            log(() -> (@info "Precompiled `$(count[])` methods from `$(sum(length, [cache, callable_cache]))` values in `$elapsed` seconds"), background)
        end
    end

    background ? (@spawn _speculate(); nothing) : _speculate()
end
