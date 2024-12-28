
# News

## v0.1.0

- `speculate(predicate, value; parameters...)`: Search for compilation directives
    - `predicate`: Filter values found in a `Module`
    - `value`: The initial value to search
    - `parameters`
        - `background`: Whether to search in a background process
        - `dry`: Whether to call `precompile` on generated methods
        - `limit`:
            The maximum number of compilable methods that may be generated from a generic method
        - `path`: A file to write compilation directives to
        - `verbosity`: Specifies which logging statements to show
- Input Speculators
    - `install_speculator`: Automatically calls `speculate` on values input to the REPL
    - `uninstall_speculator`: Removes the automatic input speculator
- `Verbosity`: A set used to specify which logging statements to show
    - `debug`: Shows each successful compilation directive
    - `review`: Summarizes the generated compilation directives
    - `silent`: Shows no logging statements
    - `warn`: Shows each unsuccessful compilation directive
- `all_modules::AllModules`: A value used to `speculate` each loaded module
