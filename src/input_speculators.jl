
struct InputSpeculator{T, F}
    parameters::T
    predicate::F
end

function (is::InputSpeculator)(x)
    _x = gensym()

    quote
        $_x = $x
        $speculate($(is.predicate), $_x; $(is.parameters)...)
        $_x
    end
end

log_input_speculator() = @info "The input speculator has been installed into the REPL"

function install_speculator!(
    (@nospecialize predicate), ast_transforms::Vector{Any}, is_background::Bool;
(@nospecialize parameters...))
    push!(ast_transforms, InputSpeculator(parameters, predicate))
    log_repl(log_input_speculator, is_background)
end

"""
    install_speculator(
        predicate = (m, _) -> m ∉ [Base, Core]; background::Bool = true,
    parameters...)

Install a hook that calls
`speculate(predicate,\u00A0value;\u00A0background,\u00A0parameters...)`
on each input `value` in the REPL.

Subsequent calls to this function may be used to replace the hook.
The hook may be removed using [`uninstall_speculator`](@ref).
This function has no effect in non-interactive sessions.

See also [`speculate`](@ref).

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.
    Since it relies on the REPL being initialized,
    it should be placed at the end of the file.

```julia-repl
julia> install_speculator(; limit = 2, verbosity = debug)
[ Info The input speculator has been installed into the REPL

julia> f() = nothing;

[ Info: Compiled `Main.f()`
julia> g(::Union{String, Symbol}) = nothing;

[ Info: Compiled `Main.g(::Symbol)`
[ Info: Compiled `Main.g(::String)`
```
"""
function install_speculator(
    predicate = (m, _) -> m ∉ [Base, Core]; background::Bool = true, parameters...
)
    @nospecialize
    if isinteractive()
        if is_repl_ready()
            ast_transforms = Base.active_repl_backend.ast_transforms
            uninstall_speculator!(ast_transforms)
            install_speculator!(predicate, ast_transforms, false; background, parameters...)
        else
            errormonitor(@spawn begin
                wait_for_repl()
                install_speculator!(
                    predicate, Base.active_repl_backend.ast_transforms, true;
                background, parameters...)
            end)
            nothing
        end
    end
end

uninstall_speculator!(ast_transforms::Vector{Any}) = filter!(
    ast_transform -> !(ast_transform isa InputSpeculator), ast_transforms
)

"""
    uninstall_speculator()

Uninstall the hook that may have previously been installed by [`install_speculator`](@ref).

```julia-repl
julia> uninstall_speculator()
[ Info: The input speculator has been uninstalled from the REPL
```
"""
uninstall_speculator() = if isinteractive() && is_repl_ready()
    uninstall_speculator!(Base.active_repl_backend.ast_transforms)
    @info "The input speculator has been uninstalled from the REPL"
end
