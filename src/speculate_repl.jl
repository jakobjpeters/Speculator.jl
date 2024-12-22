
struct InputSpeculator{T}
    parameters::T
end

function (is::InputSpeculator)(@nospecialize x)
    _x = gensym()
    quote
        $_x = $x
        $speculate($_x; $(is.parameters)...)
        $_x
    end
end

"""
    speculate_repl(::Bool = true; background::Bool = true, parameters...)

Call [`speculate`](@ref) on each input in the REPL.

This may be disabled using `speculate_repl(false)`.
Subsequent calls to this function may be used to change the keyword parameters.
This function has no effect in non-interactive sessions.

!!! tip
    Use this in a `startup.jl` file to reduce latency in the REPL.

```jldoctest
julia> speculate_repl(;
           target = all_names,
           verbosity = debug
       )
[ Info: The REPL will call `speculate` with each input

julia> module Example
           export g

           f(::Int) = nothing
           g(::Union{String, Symbol}) = nothing
       end
Main.Example
[ Info: Precompiled `Main.Example.f(::Int64)`

julia> speculate_repl(;
           target = abstract_methods | union_types,
           verbosity = debug
       )
[ Info: The REPL will call `speculate` with each input

julia> Example
Main.Example
[ Info: Precompiled `Main.Example.g(::Symbol)`
[ Info: Precompiled `Main.Example.g(::String)`

julia> speculate_repl(false)
[ Info: The REPL will not call `speculate` with each input

julia> Example
Main.Example
```
"""
function speculate_repl(install::Bool = true; background::Bool = true, parameters...)
    @nospecialize

    if isinteractive()
        ast_transforms = Base.active_repl_backend.ast_transforms
        filter!(ast_transform -> !(ast_transform isa InputSpeculator), ast_transforms)

        s = if install
            push!(ast_transforms, InputSpeculator(merge((background = background,), parameters)))
            ""
        else " not"
        end

        @info "The REPL will$s call `speculate` with each input"
    end
end
