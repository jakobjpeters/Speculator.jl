
module Speculator

# BUG: `speculate(Base; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`

import Base: eltype, firstindex, getindex, iterate, lastindex, length, show
using Base: Threads.@spawn, active_project, active_repl, Iterators.product, uniontypes
using InteractiveUtils: subtypes
using Serialization: serialize
using Statistics: mean, median
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

include("utilities.jl")
include("targets.jl")
include("verbosities.jl")
include("speculation_benchmarks.jl")

export SpeculationBenchmark, Target, Verbosity,
    abstract_methods, abstract_subtypes, all_names, any_subtypes, callable_objects,
    debug, function_subtypes, review, union_types, warn, imported_names,
    install_speculate_mode, method_types, speculate, union_all_caches

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
    function f()
        cache, count = Set(Iterators.map(objectid, ignore)), Ref(0)
        callable_cache, _verbosity = copy(cache), Speculator.verbosity(verbosity)

        elapsed = @elapsed check_cache(x;
            all_names, background, cache, callable_cache, count, dry, imported_names, max_methods,
        target = Speculator.target(target), verbosity = _verbosity)

        if review ⊆ _verbosity
            log(() -> (@info "Precompiled `$(count[])` methods from `$(sum(length, [cache, callable_cache]))` values in `$elapsed` seconds"), background)
        end
    end

    background ? (@spawn f(); nothing) : f()
end

speculate(Speculator;
    target = abstract_methods | abstract_subtypes | all_names | callable_objects | union_types)

end # Speculator
