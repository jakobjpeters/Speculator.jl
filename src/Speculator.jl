
module Speculator

import Base: |, in, show
using Base: Threads.@spawn, active_repl, uniontypes
using InteractiveUtils: subtypes
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

include("targets.jl")
include("utilities.jl")
include("verbosities.jl")

export Target, Verbosity,
    abstracts, all_names, caches, callables, debug, none, parameters,
    review, unions, warn, imported_names, install_speculate_mode, speculate

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
    speculate(::Any; abstract::Bool = false, background::Bool = true, verbosity::Verbosity = warn)

Generate and `precompile` a workload from the given value.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.
Absent new methods to compile, the difference in elapsed time between an
initial and subsequent calls to `speculate(::Any; background = false)`
may be used to estimate the compilation time.

# Input types

- `Any`: Call `speculate` for the value's type. TODO: callable objects.
- `DataType`: Call `speculate` for each of its subtypes and for each type in each of its
    method's signature. Call `precompile` for each method with a concrete signature.
- `Function`: Call `precompile` for each of its methods.
- `Module`: Call `speculate` for each of its values.
- `Union`: Call `speculate` for each of its variants.

# Keyword parameters

- `background`: Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `verbosity`: Specifies what logging statements to show.
    If this function is used as a precompilation workload,
    it should be set to [`none`](@ref) or [`warn`](@ref).
    See also [`Verbosity`](@ref).

# Examples
```jldoctest
julia> speculate(Speculator)
```
"""
function speculate(x;
    background::Bool = true, target::Target = abstracts | unions, verbosity::Verbosity = warn)
    function f()
        cache = Set{UInt}()
        check_cache(x; all_names, background, cache, imported_names, target, verbosity)

        if review in verbosity
            log(() -> (@info "Speculated `$(length(cache))` values"), background)
        end
    end

    background ? (@spawn f(); nothing) : f()
end

speculate(Speculator)

end # Speculator
