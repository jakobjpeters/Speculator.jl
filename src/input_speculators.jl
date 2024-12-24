
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

is_repl_ready() = isdefined(Base, :active_repl_backend)

log_input_speculator() = @info "The input speculator has been installed into the REPL"

function wait_for_repl()
    _time = time()

    while !(_is_repl_ready = is_repl_ready()) && time() - _time < 10
        sleep(0.1)
    end

    _is_repl_ready
end

function install_speculator!(
    (@nospecialize predicate), ast_transforms::Vector{Any}, is_background::Bool;
(@nospecialize parameters...))
    push!(ast_transforms, InputSpeculator(parameters, predicate))

    if is_background log_background_repl(log_input_speculator, true)
    else log_foreground_repl(log_input_speculator, true)
    end
end

"""
    install_speculator(predicate = $default_predicate; background::Bool = true, parameters...)

Install an input speculator that calls
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
[ Info: Compiled `Main.Example.f()`

julia> g(::Union{String, Symbol}) = nothing;
[ Info: Compiled `Main.Example.g(::String)`
[ Info: Compiled `Main.Example.g(::Symbol)`
```
"""
function install_speculator(predicate = default_predicate; background::Bool = true, parameters...)
    @nospecialize
    if isinteractive()
        if is_repl_ready()
            ast_transforms = Base.active_repl_backend.ast_transforms
            uninstall_speculator!(ast_transforms)
            install_speculator!(predicate, ast_transforms, false; background, parameters...)
        else
            errormonitor(@spawn begin
                if wait_for_repl()
                    install_speculator!(
                        predicate, Base.active_repl_backend.ast_transforms, true;
                    background, parameters...)
                else
                    log_background_repl(true) do
                        @info "The input speculator has failed to be installed into the REPL"
                    end
                end
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
    log_foreground_repl(true) do
        @info "The input speculator has been uninstalled from the REPL"
    end
end
