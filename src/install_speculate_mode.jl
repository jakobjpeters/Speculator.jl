
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
