
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
    speculate_repl(
        predicate = $default_predicate,
        install::Bool = true;
        background::Bool = true,
    parameters...)

Call [`speculate`](@ref) on each input in the REPL.

This may be disabled using `speculate_repl(false)`.
Subsequent calls to this function may be used to change the keyword parameters.
This function has no effect in non-interactive sessions.

To benchmark the compilation time of a workload, see also [`SpeculationBenchmark`](@ref).

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.

```jldoctest
julia> speculate_repl(; limit = 2, verbosity = debug)
[ Info: The REPL will call `speculate` with each input

julia> f() = nothing;
[ Info: Precompiled `Main.Example.f()`

julia> g(::Union{String, Symbol}) = nothing;
[ Info: Precompiled `Main.Example.g(::String)`
[ Info: Precompiled `Main.Example.g(::Symbol)`
```
"""
function speculate_repl(
    predicate = default_predicate,
    install::Bool = true;
    background::Bool = true,
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
