
# History

## v0.1.0

- `speculate`: Search for compilation directives
- `install_speculator`: Automatically calls `speculate` on values input to the REPL
- `uninstall_speculator`: Removes the automatic input speculator
- `Verbosity`: A set used to specify which logging statements to show in `speculate`
    - `debug`: Shows each successful compilation directive
    - `review`: Summarizes the generated compilation directives
    - `silent`: Shows no logging statements
    - `warn`: Shows each unsuccessful compilation directive
- `all_modules::AllModules`: A singleton constant used to `speculate` every loaded module
