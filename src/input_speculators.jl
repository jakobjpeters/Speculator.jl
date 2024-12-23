
struct InputSpeculator{T, F}
    parameters::T
    predicate::F
end

function (is::InputSpeculator)(@nospecialize x)
    _x = gensym()

    quote
        $_x = $x
        $speculate($(is.predicate), $_x; $(is.parameters)...)
        $_x
    end
end

"""
    install_speculator(predicate = $default_predicate; background::Bool = true, parameters...)

Install a hook that calls
`speculate(predicate,\u00A0value;\u00A0background,\u00A0parameters...)`
on each input `value` in the REPL.

Subsequent calls to this function may be used to replace the hook.
The hook may be removed using [`uninstall_speculator`](@ref).
This function has no effect in non-interactive sessions.

See also [`speculate`](@ref).

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.

```julia-repl
julia> install_speculator(; limit = 2, verbosity = debug)
[ Info The speculator REPL hook has been installed

julia> f() = nothing;
[ Info: Compiled `Main.Example.f()`

julia> g(::Union{String, Symbol}) = nothing;
[ Info: Compiled `Main.Example.g(::String)`
[ Info: Compiled `Main.Example.g(::Symbol)`
```
"""
function install_speculator(predicate = default_predicate; background::Bool = true, parameters...)
    @nospecialize
    if isinteractive()
        ast_transforms = Base.active_repl_backend.ast_transforms
        _uninstall_speculator(ast_transforms)
        push!(ast_transforms, InputSpeculator(
            merge((background = background,), parameters), predicate)
        )
        @info "The speculator REPL hook has been installed"
    end
end

_uninstall_speculator(ast_transforms) = filter!(
    ast_transform -> !(ast_transform isa InputSpeculator), ast_transforms
)

"""
    uninstall_speculator()

Uninstall the hook that may have previously been installed by [`install_speculator`](@ref).

```julia-repl
julia> uninstall_speculator()
[ Info: The speculator REPL hook has been uninstalled
```
"""
uninstall_speculator() = if isinteractive()
    _uninstall_speculator(Base.active_repl_backend.ast_transforms)
    @info "The speculator REPL hook has been uninstalled"
end
