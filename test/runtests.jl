
using Aqua, ExplicitImports, MethodAnalysis, PrecompileSignatures, Speculator, Test

module X end

Aqua.test_all(Speculator)

@testset "ExplicitImports.jl" begin
    for f in [
        check_no_implicit_imports,
        check_all_explicit_imports_via_owners,
        check_no_stale_explicit_imports,
        check_all_qualified_accesses_via_owners,
        check_no_self_qualified_accesses
    ]
        @test isnothing(f(Speculator))
    end

    @test isnothing(check_all_explicit_imports_are_public(Speculator; ignore = (
        :IdSet,
        :MethodList,
        :TypeofBottom,
        :Typeof,
        :activate,
        :add,
        :develop,
        :instantiate,
        :isdeprecated,
        :isvarargtype,
        :loaded_modules_array,
        :mul_with_overflow,
        :resolve,
        :specializations,
        :typename,
        :uniontypes,
        :unsorted_names
    )))
    @test isnothing(check_all_qualified_accesses_are_public(Speculator; ignore = (
        :active_repl, :active_repl_backend
    )))
end

@testset "`Verbosity`" begin
    verbosities = [debug, review, silent, warn]
    combined_verbosities = reduce(union, verbosities)

    @test string(combined_verbosities) == "(debug ∪ review ∪ warn)::Verbosity"
    @test combined_verbosities == debug ∪ review ∪ warn
    @test combined_verbosities ⊆ debug ∪ review ∪ warn
    @test combined_verbosities.value == 7
    @test all(v -> v ⊆ v, verbosities)
    @test all(v -> silent ⊆ v, verbosities)
    @test all(((v, n),) -> string(v) == n * "::Verbosity", [
        debug => "debug", review => "review", silent => "silent", warn => "warn"
    ])
end

@testset "`initialize_parameters`" begin
    @test_logs (
        :info,
        r"^Generated `0` methods from `0` generic methods in `\d+\.\d{4}` seconds$"
    ) Speculator.initialize_parameters(nothing, "", false;
        background_repl = false,
        dry = true,
        limit = 1,
        predicate = Speculator.default_predicate,
        verbosity = review
    )

    @test_logs (
        :info,
        r"^Generated `0` methods from `0` generic methods in `\d+\.\d{4}` seconds\nCompiled `0`\nSkipped  `0`\nWarned   `0`$"
    ) Speculator.initialize_parameters(nothing, "", false;
        background_repl = false,
        dry = false,
        limit = 1,
        predicate = Speculator.default_predicate,
        verbosity = review
    )
end

@testset "`signature`" begin
    types = Type[]
    @test Speculator.signature(String, types) == "(::String)()"
    @test Speculator.signature(Type{String}, types) == "String()"
    @test Speculator.signature(typeof(string), types) == "string()"
    @test Speculator.signature(Type{<:AbstractString}, types) == "(::Type{<:AbstractString})()"
    @test Speculator.signature(Union{String, LazyString}, types) == "Union{LazyString, String}()"
    @test Speculator.signature(Union{}, types) == "Union{}()"
    @test Speculator.signature(Nothing, [
        String,
        Type{String},
        typeof(string),
        Type{<:AbstractString},
        Union{String, LazyString},
        Union{}
    ]) == "nothing(::String, ::Type{String}, ::typeof(string), ::Type{<:AbstractString}, ::Union{LazyString, String}, ::Union{})"
end

@testset "`speculate_repl`" begin
    is = Speculator.InputSpeculator((), Returns(true))
    x = Base.remove_linenums!(is(true))
    lines = split(string(x), '\n')

    b = false
    redirect_stderr(() -> b = eval(x), devnull)
    @test b

    for (line, regex) in zip(lines, [
        r"begin",
        r" {4}var\"##\d+\" = true",
        r" {4}\(Speculator.speculate\)\(Returns{Bool}\(true\), var\"##\d+\"; \(\)\.\.\.\)",
        r" {4}var\"##\d+\"",
        r"end"
    ])
        @test !isnothing(match(regex, line))
    end

    _is = Speculator.InputSpeculator((
        background = true,
        dry = true,
        limit = 8,
        path = "precompile.jl",
        verbosity = debug ∪ review
    ), Base.isexported)
    _x = Base.remove_linenums!(_is(:(f() = true)))
    _lines = split(string(_x), '\n')

    _b = false
    redirect_stderr(() -> _b = invokelatest(eval(_x)), devnull)
    @test _b

    for (line, regex) in zip(_lines, [
        r"begin",
        r" {4}var\"##\d+\" = \(f\(\) = begin",
        r" {16}true",
        r" {12}end\)",
        r" {4}\(Speculator.speculate\)\(Base\.isexported, var\"##\d+\"; \(background = true, dry = true, limit = 8, path = \"precompile.jl\", verbosity = \(debug ∪ review\)::Verbosity\)\.\.\.\)",
        r" {4}var\"##\d+\"",
        r"end"
    ])
        @test !isnothing(match(regex, line))
    end

    # TODO: test `speculate_repl`
    # @eval Base is_interactive = true
    # @test_logs (:info, "The REPL will call `speculate` with each input") speculate_repl()
    # @test_logs(
    #     (:info, "The REPL will not call `speculate` with each input"),
    #     speculate_repl(; install = false)
    # )
    # @eval Base is_interactive = false
end

function count_methods(predicate, value; parameters...)
   pipe = Pipe()
   redirect_stderr(pipe) do
       speculate(predicate, value; path = tempname(), verbosity = review, parameters...)
   end
   close(pipe[2])
   parse(Int, only(match(r"`(\d+)` generic", read(pipe, String)).captures))
end
count_methods(value; parameters...) = count_methods(
    Speculator.default_predicate, value;
parameters...)

speculator_count = count_methods(all_modules)
precompile_signatures_count = length(
    PrecompileSignatures.precompilables(Base.loaded_modules_array(),
PrecompileSignatures.Config(; split_unions = false)))
method_analysis_count = 0
function count_method_analysis(x::Method)
    sig = x.sig
    if sig isa DataType && !(parentmodule(x) == Core && Tuple <: sig)
        types = sig.types[2:end]
        if (
            (isempty(types) || !Base.isvarargtype(last(types))) &&
            all(eachindex(types)) do i
                isconcretetype(types[i]) || Speculator.is_subset(1, x.nospecialize >> (i - 1))
            end
        )
            global method_analysis_count += 1
        end
    end
    true
end
count_method_analysis((@nospecialize _)) = true
visit(count_method_analysis)
@test method_analysis_count < speculator_count
@test precompile_signatures_count < speculator_count

path = "precompile.jl"
rm(path; force = true)
s = "Skipping speculation because it is not being ran during precompilation, an interactive session, or to save a workload"
@test_warn "$s" speculate(X; path, dry = true)
@test !isfile(path)
speculate(X; path)
@test isfile(path)

path = tempname()
@test_nowarn speculate(all_modules; path)
@test_broken (include(path); true)
# include(x -> :(@test $x), path)

@test issorted(map(limit -> count_methods(all_modules; limit), 1:4))

@test count_methods(Returns(false), all_modules) == 0
@test count_methods(Returns(false), () -> nothing) == 1

rm(path)

# speculate(Base)
# count precompiled + skipped
# speculate(Base)
# test that 0 were compiled and total number were skipped

#=
julia> (::String)() = nothing;

julia> speculate(""; verbosity = debug)
[ Info: Skipped `(::String)()`

julia> speculate(String; verbosity = debug)
[ Info: Skipped `String(::Vector{UInt8})`
...

julia> speculate(string; verbosity = debug)
[ Info: Skipped `string(::Base.UUID)`
...
=#

# `include("scripts/trial.jl")`
