
module Speculator

using Base: Threads.@spawn, active_repl, uniontypes
using InteractiveUtils: subtypes
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

export Verbosity, debug, none, warn, install_speculate_mode, speculate

function log(f, background)
    flag = background && isdefined(Base, :active_repl)
    flag && print(stderr, "\33[2K\r\e[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

signature(f, types) =
    string(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

"""
    Verbosity

An `enum` that determines what logging statements are shown during [`speculate`](@ref).

In increasing verbosity, the variants are
[`none`](@ref), [`warn`](@ref), and [`debug`](@ref).

```jldoctest
julia> Verbosity
Enum Verbosity:
none = 0
warn = 1
debug = 2
```
"""
@enum Verbosity none warn debug

@doc """
    none

A variant of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show no logging statements.

# Examples

```jldoctest
julia> none
none::Verbsosity = 0
```
""" none

@doc """
    warn

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity = 1
```
""" warn

@doc """
    debug

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref) should show
each successful call to `precompile` and warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity = 2
```
""" debug

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

___speculate(x; background, verbosity) =
    for method in methods(x)
        sig = method.sig

        if isconcretetype(sig)
            types = getfield(sig, 3)[(begin + 1):end]

            if precompile(x, ntuple(i -> types[i], length(types)))
                verbosity == debug &&
                    log(() -> (@info "Precompiled `$(signature(x, types))`"), background)
            elseif verbosity > none
                log(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))"), background)
            end
        end
    end

function __speculate(x::DataType, cache; kwargs...)
    ___speculate(x; kwargs...)

    for subtype in subtypes(x)
        _speculate(subtype, cache; kwargs...)
    end
end
__speculate(x::Function, cache; kwargs...) = ___speculate(x; kwargs...)
__speculate(x::Module, cache; kwargs...) =
    for name in names(x; all = true)
        isdefined(x, name) && _speculate(getfield(x, name), cache; kwargs...)
    end
__speculate(::Type, cache; _...) = nothing
__speculate(x::Union, cache; kwargs...) = for type in uniontypes(x)
    _speculate(type, cache; kwargs...)
end
__speculate(::T, cache; kwargs...) where T = _speculate(T, cache; kwargs...)

function _speculate(x, cache; kwargs...)
    object_id = objectid(x)

    if !(object_id in cache)
        push!(cache, object_id)
        __speculate(x, cache; kwargs...)
    end
end

"""
    speculate(::Any; background::Bool = true, verbosity::Verbosity = warn)

Generate and `precompile` a workload from the given value.

This function can be called repeatedly with the same value,
which may be useful if there are new methods to precompile.
Absent new methods to compile, the difference in elapsed time between an
initial and subsequent calls to `speculate(::Any; background = false)`
may be used to estimate the compilation time.

# Input types

- `Any`: Call `speculate` on the value's type.
- `DataType`: Call `precompile` for each method with a concrete signature.
    Call `speculate` for each subtype.
- `Function`: Call `precompile` for each method with a concrete signature.
- `Module`: Call `speculate` on each of its values.
- `Type`: Do nothing.
- `Union`: Call `speculate` on each variant.

# Keyword parameters

- `background`: Specifies whether to precompile on a thread in the `:default` pool.
    The number of available threads can be determined using `Threads.nthreads(:default)`.
- `verbosity`: Specifies what logging statements to show.
    If this function is used as a precompilation workload,
    it should be set to [`none`](@ref) or [`warn`](@ref).
    See also [`Verbosity`](@ref).

!!! tip
    This function is safe for threads.

# Examples
```jldoctest
julia> speculate(Speculator)
```
"""
function speculate(x; background::Bool = true, verbosity::Verbosity = warn)
    cache = Set{UInt}()
    background ? (@spawn _speculate(x, cache; background, verbosity)) :
        _speculate(x, cache; background, verbosity)
    nothing
end

speculate(Speculator)

end # Speculator
