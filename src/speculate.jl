
function ___speculate((@nospecialize x), parameters)
    elapsed = @elapsed check_ignore!(x, parameters)

    if review ⊆ parameters.verbosity
        counters = parameters.counters
        dry = parameters.dry

        log_repl(parameters) do
            values = length(parameters.ignore)
            seconds = round_time(elapsed)
            s = " methods from `$values` values in `$seconds` seconds"

            if dry @info "Found `$(counters[found])`$s"
            else
                _precompiled, _skipped, _warned =
                    map(s -> counters[s], [precompiled, skipped, warned])
                @info "Precompiled `$_precompiled`, skipped `$_skipped`, and warned `$_warned`$s"
            end
        end
    end
end

__speculate((@nospecialize x::Some), parameters) = ___speculate(something(x), parameters)
__speculate(::Nothing, parameters) = for _module in loaded_modules_array()
    ___speculate(_module, parameters)
end

function _speculate(x;
    background::Bool = false,
    dry::Bool = false,
    ignore = default_ignore,
    maximum_methods::Integer = default_maximum_methods,
    path::String = "precompile.jl",
    target::Union{Target, Nothing} = default_target,
    verbosity::Union{Verbosity, Nothing} = warn
)
    @nospecialize

    generate = !(dry || isempty(path))
    _verbosity = Speculator.verbosity(verbosity)

    open(generate ? path : tempname(); write = true) do file
        parameters = Parameters(
            background && isinteractive(),
            Dict(map(s -> s => 0, dry ? [found] : [skipped, precompiled, warned])),
            dry,
            file,
            generate,
            IdSet{Any}(ignore),
            maximum_methods,
            IdDict{Type, Vector{Type}}(),
            IdDict{DataType, Vector{Type}}(),
            Speculator.target(target),
            _verbosity,
        )
        background ? (@spawn __speculate(x, parameters); nothing) : __speculate(x, parameters)
    end
end

function speculate(x; parameters...)
    @nospecialize
    _speculate(Some(x); parameters...)
end

function speculate(; parameters...)
    @nospecialize
    _speculate(nothing; parameters...)
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
julia> speculate(Speculator)
```
"""
speculate
