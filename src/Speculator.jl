
module Speculator

using Base: Threads.@spawn, active_repl, uniontypes
using InteractiveUtils: subtypes
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

export Verbosity, debug, none, review, warn, install_speculate_mode, speculate

function cache(f, x; cache, kwargs...)
    object_id = objectid(x)

    if !(object_id in cache)
        push!(cache, object_id)
        f(x; cache, kwargs...)
    end
end

check_cache(x; kwargs...) = cache((x; kwargs...) -> speculate_cached(x; kwargs...), x; kwargs...)

leaf_types(x::DataType) = subtypes(x)
leaf_types(x::Union) = uniontypes(x)

function log(f, background)
    flag = background && isdefined(Base, :active_repl)
    flag && print(stderr, "\33[2K\r\33[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

maybe_check_cache(::Nothing; _...) = nothing
maybe_check_cache(x; kwargs...) = check_cache(x; kwargs...)

precompile_methods(x; kwargs...) =
    for method in methods(x)
        precompile_method(x, method.sig; kwargs...)
    end

precompile_method(x, sig::DataType; background, verbosity, kwargs...) =
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if all(isconcretetype, parameter_types)
            concrete_types = (parameter_types...,)

            if precompile(x, concrete_types)
                verbosity == debug &&
                    log(() -> (@info "Precompiled `$(signature(x, concrete_types))`"), background)
            elseif verbosity > none
                log(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, concrete_types))`"), background)
            end
        end

        for parameter_type in parameter_types
            check_cache(parameter_type; background, verbosity, kwargs...)
        end
    end
precompile_method(x, ::UnionAll; _...) = nothing

signature(f, types) =
    repr(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

speculate_cached(x::Function; kwargs...) = precompile_methods(x; kwargs...)
speculate_cached(x::Module; kwargs...) = for name in names(x; all = true)
    isdefined(x, name) && check_cache(getfield(x, name); kwargs...)
end
function speculate_cached(x::Union{DataType, Union}; kwargs...)
    precompile_methods(x; kwargs...)

    for type in leaf_types(x)
        check_cache(type; kwargs...)
    end
end
speculate_cached(x::UnionAll; kwargs...) = speculate_union_all(x; kwargs...)
function speculate_cached(x::T; kwargs...) where T
    check_cache(T; kwargs...)
    precompile_methods(x)
end

speculate_union_all(x::DataType; kwargs...) = cache((x; kwargs...) -> foreach(
    maybe_type -> maybe_check_cache(maybe_type; kwargs...), x.name.cache), x; kwargs...)
speculate_union_all(x::UnionAll; kwargs...) =
    cache((x; kwargs...) -> speculate_union_all(x.body; kwargs...), x; kwargs...)
speculate_union_all(x::Union; kwargs...) = cache((x; kwargs...) -> foreach(
    type -> speculate_union_all(type; kwargs...), uniontypes(x)), x; kwargs...)

"""
    Verbosity

An `enum` that determines what logging statements are shown during [`speculate`](@ref).

In increasing verbosity, the variants are [`none`](@ref),
[`warn`](@ref), [`review`](@ref), and [`debug`](@ref).

```jldoctest
julia> Verbosity
Enum Verbosity:
none = 0
warn = 1
review = 2
debug = 3
```
"""
@enum Verbosity none warn review debug

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
    review

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref) should show warnings
for failed calls to `precompile` and the total number of values that have been speculated.

# Examples

```jldoctest
julia> debug
debug::Verbosity = 2
```
""" review

@doc """
    debug

A variant of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show each successful call to `precompile`, the total number of values
that have been speculated, and warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity = 3
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
function speculate(x; background::Bool = true, verbosity::Verbosity = warn)
    function f()
        cache = Set{UInt}()
        check_cache(x; background, cache, verbosity)

        if verbosity ≥ review
            log(() -> (@info "Speculated `$(length(cache))` values"), background)
        end
    end

    background ? (@spawn f(); nothing) : f()
end

speculate(Speculator)

end # Speculator
