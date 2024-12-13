
module Speculator

# BUG: `speculate(Base; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`

using Base: Threads.@spawn, active_repl, Iterators.product, uniontypes
using InteractiveUtils: subtypes
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

include("utilities.jl")
include("targets.jl")
include("verbosities.jl")

export Target, Verbosity,
    abstract_methods, abstract_subtypes, all_names, any_subtypes, callable_objects,
    debug, function_subtypes, review, union_types, warn, imported_names,
    install_speculate_mode, method_types, speculate, time_precompilation, union_all_caches

"""
    install_speculate_mode(;
        start_key = "\\M-s", prompt_text = "speculate> ", prompt_color = :cyan,
    kwargs...)

Install a REPL mode where input implicitly calls [`speculate`](@ref).

The default start keys are pressing both the \\[Meta\\]
(also known as [Alt]) and [s] keys at the same time.
The `prompt_text` specifies the start of each line reading user input.
The `prompt_color` can be any of those in `Base.text_colors`.
Additional keyword parameters are passed to `speculate`.

# Examples

```jldoctest
julia> install_speculate_mode()
[ Info: The `speculate` REPL mode has been installed. Press [\\M-s] to enter and [Backspace] to exit.
```
"""
function install_speculate_mode(; start_key = "\\M-s",
    prompt_text = "speculate> ", prompt_color = :cyan, kwargs...)
    initrepl(; start_key, prompt_color, prompt_text, mode_name = :speculate,
        startup_text = false, valid_input_checker = complete_julia) do s
        x = gensym()
        quote
            $x = $(Meta.parse(s))
            speculate($x; $kwargs...)
            $x
        end
    end
    @info "The `speculate` REPL mode has been installed. Press [$start_key] to enter and [Backspace] to exit."
end

"""
    speculate(::Any;
        background::Bool = true,
        dry::Bool = false,
        ignore = $default_ignore,
        target::Union{Target, Nothing} = $default_target,
        verbosity::Union{Verbosity, Nothing} = warn
    )

Generate and `precompile` a workload from the given value.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.

# Keyword parameters

- `background`: Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `dry`: Specifies whether to actually run `precompile`.
    This is useful for [`time_precompilation`](@ref).
- `ignore`: An iterable of values that will not be speculated.
- `target`: Specifies what methods to precompile. See also [`Target`](@ref).
- `verbosity`: Specifies what logging statements to show.
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
    target::Union{Target, Nothing} = default_target,
    verbosity::Union{Verbosity, Nothing} = warn
)
    function f()
        cache, count = Set(Iterators.map(objectid, ignore)), Ref(0)
        callable_cache, _verbosity = copy(cache), Speculator.verbosity(verbosity)

        elapsed = @elapsed check_cache(x;
            all_names, background, cache, callable_cache, count, dry, imported_names,
        target = Speculator.target(target), verbosity = _verbosity)

        if review ⊆ _verbosity
            log(() -> (@info "Precompiled `$(count[])` methods from `$(sum(length, [cache, callable_cache]))` values in `$elapsed` seconds"), background)
        end
    end

    background ? (@spawn f(); nothing) : f()
end

"""
    time_precompilation(::Any; ignore = $default_ignore, target::$(typeof(default_target)) = $default_target)

Estimate the compilation time saved by [`speculate`](@ref).

This function runs
`speculate(::Any;\u00A0ignore,\u00A0target,\u00A0background\u00A0=\u00A0false,\u00A0verbosity\u00A0=\u00A0nothing)`
sequentially with `dry = true` to compile methods in Speculator.jl, `dry = false`
to measure the runtime of methods in Speculator.jl and calls to `precompile`,
and `dry = false` to measure the runtime of methods in
Speculator.jl and the overhead for repeated calls to `precompile`.
The difference between the second and third runs is returned
as an estimate of the runtime of calls to `precompile`.

See also [`target`](@ref).

!!! info
    Previous calls to `speculate` and `precompile` may underestimate the
    runtime if there is overlap between the previous and current workloads.
    Therefore, this function should be used once at the beginning of a session.
"""
function time_precompilation(x; ignore = default_ignore, target = default_target)
    @nospecialize
    f(dry) = @elapsed speculate(x; dry, ignore, target, background = false, verbosity = nothing)
    f(true)
    f(false) - f(false)
end

speculate(Speculator;
    target = abstract_methods | abstract_subtypes | all_names | callable_objects | union_types)

end # Speculator
