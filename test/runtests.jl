
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
        :active_project,
        :add,
        :develop,
        :instantiate,
        :isvarargtype,
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
    combined_verbosities = reduce(|, verbosities)
    @test string(combined_verbosities) == "(debug | review | warn)::Verbosity"
    @test combined_verbosities == debug | review | warn
    @test combined_verbosities.value == 7
    @test all(v -> v ⊆ v, verbosities)
    @test all(v -> silent ⊆ v, verbosities)
    @test all(((v, n),) -> string(v) == n * "::Verbosity", [
        debug => "debug", review => "review", silent => "silent", warn => "warn"
    ])
end

@testset "`SpeculationBenchmark`" begin
    sb = SpeculationBenchmark(Test)
    times = sb.times

    @test all(≥(0), sb)

    for i in eachindex(times)
        times[i] = 0.0
    end

    @test eltype(sb) <: Float64
    @test firstindex(sb) == 1
    @test (sb[1]; true)
    @test iterate(sb) == (0.0, 2)
    @test iterate(sb, 2) == (0.0, 3)
    @test lastindex(sb) == 8
    @test length(sb) == 8
    @test sprint(show, MIME"text/plain"(), sb) == "Precompilation benchmark with `8` samples:\n  Mean:      `0.0000`\n  Median     `0.0000`\n  Minimum:   `0.0000`\n  Maximum:   `0.0000`"
    # TODO: test display of mean, median, minimum, and maximum
end

@testset "`speculate_repl`" begin
    is = Speculator.InputSpeculator((), Returns(true))
    x = Base.remove_linenums!(is(true))
    lines = split(string(x), '\n')

    @test eval(x)

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
        verbosity = debug | review
    ), Base.isexported)
    _x = Base.remove_linenums!(_is(:(f() = true)))
    _lines = split(string(_x), '\n')

    @test eval(_x)()

    for (line, regex) in zip(_lines, [
        r"begin",
        r" {4}var\"##\d+\" = \(f\(\) = begin",
        r" {16}true",
        r" {12}end\)",
        r" {4}\(Speculator.speculate\)\(Base\.isexported, var\"##\d+\"; \(background = true, dry = true, limit = 8, path = \"precompile.jl\", verbosity = \(debug | review\)::Verbosity\)\.\.\.\)",
        r" {4}var\"##\d+\"",
        r"end"
    ])
        @test !isnothing(match(regex, line))
    end

    # TODO: test `speculate_repl`
    # @test_logs (:info, "The REPL will call `speculate` with each input") speculate_repl()
    # @test_logs(
    #     (:info, "The REPL will not call `speculate` with each input"),
    #     speculate_repl(; install = false)
    # )
end

function count_methods(predicate, value; parameters...)
    path = tempname()
    speculate(predicate, value; path, parameters...)
    length(readlines(path))
end
count_methods(value; parameters...) = count_methods(
    Speculator.default_predicate, value;
parameters...)

speculator_count = count_methods(Base)
precompile_signatures_count = length(
    PrecompileSignatures.precompilables(Base, PrecompileSignatures.Config(; split_unions = false))
)
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
visit(count_method_analysis, Base)
@test method_analysis_count < speculator_count + 5
@test precompile_signatures_count < speculator_count

path = "precompile.jl"
rm(path; force = true)
speculate(X; path, dry = true)
@test !isfile(path)
speculate(X; path)
@test isfile(path)

path = tempname()
@test_nowarn speculate(Base; path)
@test_broken (include(path); true)
# include(x -> :(@test $x), path)

@test issorted(map(limit -> count_methods(Base; limit), 1:4))

@test count_methods(Returns(false)) == 0
@test count_methods(Returns(false), () -> nothing) == 1

rm(path)

# speculate(Base)
# count precompiled + skipped
# speculate(Base)
# test that 0 were precompiled and total number were skipped

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
