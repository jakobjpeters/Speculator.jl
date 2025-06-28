
struct InputSpeculator{F, T}
    predicate::F
    parameters::T
end

function (input_speculator::InputSpeculator)(value)
    name = gensym()

    quote
        $name = $value
        $speculate($(input_speculator.predicate), $name; $(input_speculator.parameters)...)
        $name
    end
end

function install_speculator!(
    (@nospecialize predicate),
    ast_transforms::Vector{Any};
    (@nospecialize parameters...)
)
    push!(ast_transforms, InputSpeculator(predicate, parameters))
end

"""
    install_speculator(
        predicate = (_module::Module, ::Symbol) -> _module ∉ (Base, Core);
        background::Bool = true,
        parameters...
    )

Install a hook that calls
`speculate(predicate,\u00A0value;\u00A0background,\u00A0parameters...)`
on each input `value` in the REPL.

Subsequent calls to this function may be used to replace the hook.
The hook may be removed using [`uninstall_speculator`](@ref).

See also [`speculate`](@ref).

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.
    Since it relies on the REPL being initialized,
    it should be placed at the end of the file.

!!! note
    This function has no effect in non-interactive sessions.
```julia-repl
julia> install_speculator(; limit = 2, verbosity = debug)

julia> f() = nothing;

[ Info: Compiled `Main.f()`
julia> g(::Union{String, Symbol}) = nothing;

[ Info: Compiled `Main.g(::Symbol)`
[ Info: Compiled `Main.g(::String)`
```
"""
function install_speculator(
    predicate = (_module::Module, ::Symbol) -> m ∉ (Base, Core);
    background::Bool = true,
    parameters...
)
    @nospecialize
    if isinteractive()
        if is_repl_ready()
            ast_transforms = Base.active_repl_backend.ast_transforms
            uninstall_speculator!(ast_transforms)
            install_speculator!(predicate, ast_transforms; background, parameters...)
        else
            errormonitor(@spawn begin
                wait_for_repl()
                install_speculator!(
                    predicate,
                    Base.active_repl_backend.ast_transforms;
                    background,
                    parameters...
                )
            end)
        end

        nothing
    end
end

uninstall_speculator!(ast_transforms::Vector{Any}) = filter!(
    ast_transform -> !(ast_transform isa InputSpeculator), ast_transforms
)

"""
    uninstall_speculator()

Uninstall the hook that may have previously been installed by [`install_speculator`](@ref).

!!! note
    This function has no effect in non-interactive sessions.
```jldoctest
julia> uninstall_speculator()
```
"""
uninstall_speculator() = if isinteractive() && is_repl_ready()
    uninstall_speculator!(Base.active_repl_backend.ast_transforms)
    nothing
end
