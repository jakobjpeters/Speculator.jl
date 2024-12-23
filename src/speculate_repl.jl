
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
    speculate_repl(predicate = $default_predicate;
        install::Bool = true, background::Bool = true,
    parameters...)

Install a hook that calls
`speculate(predicate,\u00A0value;\u00A0background,\u00A0parameters...)`
on each input `value` in the REPL.

Subsequent calls to this function may be used to replace the hook.
The hook may be removed using `speculate_repl(;\u00A0install\u00A0=\u00A0false)`.
This function has no effect in non-interactive sessions.

See also [`SpeculationBenchmark`](@ref) and [`speculate`](@ref).

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.

```julia-repl
julia> speculate_repl(; limit = 2, verbosity = debug)
[ Info: The REPL will call `speculate` with each input

julia> f() = nothing;
[ Info: Compiled `Main.Example.f()`

julia> g(::Union{String, Symbol}) = nothing;
[ Info: Compiled `Main.Example.g(::String)`
[ Info: Compiled `Main.Example.g(::Symbol)`

julia> speculate_repl(; install = false)
[ Info: The REPL will not call `speculate` with each input
```
"""
function speculate_repl(predicate = default_predicate;
    background::Bool = true, install::Bool = true,
parameters...)
    @nospecialize
    if isinteractive()
        ast_transforms = Base.active_repl_backend.ast_transforms
        filter!(ast_transform -> !(ast_transform isa InputSpeculator), ast_transforms)
        s = begin
            if install
                push!(
                    ast_transforms,
                    InputSpeculator(merge((background = background,), parameters), predicate)
                )
                ""
            else " not"
            end
        end
        @info "The REPL will$s call `speculate` with each input"
    end
end
