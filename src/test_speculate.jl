
function test_speculate(
    predicate,
    value;
    limit::Int = default_limit,
    verbosity::Verbosity = default_verbosity
)
    @nospecialize
    @testset "`test_speculate`" initialize_parameters(
        value,
        default_path,
        false;
        limit,
        predicate,
        verbosity,
        background_repl = false,
        compile = true,
        test = true
    )
end

test_speculate(value; parameters...) = test_speculate(default_predicate, value; parameters...)

@doc """
    test_speculate(
        predicate = (::Module, ::Symbol) -> true,
        value;
        limit::Int = $default_limit,
        verbosity::Verbosity = compile ∪ warn
    )
""" test_speculate
