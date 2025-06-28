
module TestSpeculator

using Speculator
using Test: @test_broken, @test_nowarn, @test_throws, @testset, @test
using MethodAnalysis, PrecompileSignatures

module X end

@testset "`Verbosity`" begin
    verbosities = instances(Verbosity)
    combined_verbosities = reduce(∪, verbosities)

    @test verbosities == (silent, compile, pass, review, warn)
    @test string(combined_verbosities) == "compile ∪ pass ∪ review ∪ warn"
    @test combined_verbosities == compile ∪ pass ∪ review ∪ warn
    @test collect(combined_verbosities) isa Vector{Verbosity}
    @test combined_verbosities ⊆ compile ∪ pass ∪ review ∪ warn
    @test combined_verbosities.value == 15
    @test all(v -> v ⊆ v, verbosities)
    @test all(v -> silent ⊆ v, verbosities)
    @test all(((v, n),) -> string(v) == n, [
        compile => "compile"
        pass => "pass"
        review => "review"
        silent => "silent"
        warn => "warn"
    ])
    @test isdisjoint(compile, review)
    @test isempty(silent)
    @test !isempty(compile)
    @test issetequal(silent ∪ compile ∪ review, compile ∪ review)
    @test setdiff(compile, compile) == silent
    @test setdiff(review ∪ compile, compile) == review
    @test symdiff(review, review, compile) == compile
    @test symdiff(review ∪ compile, compile ∪ warn, warn ∪ review) == silent
end

# @testset "`initialize_parameters`" begin
#     @test_logs (
#         :info,
#         r"^Generated 0 compilable signatures from 0 methods in \d+\.\d{4} seconds$"
#     ) Speculator.initialize_parameters(nothing, "", false;
#         background_repl = false,
#         compile = false,
#         limit = 1,
#         predicate = Speculator.default_predicate,
#         verbosity = review
#     )

#     @test_logs (
#         :info,
#         r"^Generated 0 compilable signatures from 0 methods in \d+\.\d{4} seconds\n- compile: 0\n- skip: 0\n- warn: 0$"
#     ) Speculator.initialize_parameters(nothing, "", false;
#         background_repl = false,
#         compile = true,
#         limit = 1,
#         predicate = Speculator.default_predicate,
#         verbosity = review
#     )
# end

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

@test !Speculator.is_repl_ready()

ast_transforms = []
@test (Speculator.install_speculator!(Returns(true), ast_transforms); true)
@test only(ast_transforms) isa Speculator.InputSpeculator
@test isempty(Speculator.uninstall_speculator!(ast_transforms))
@test (uninstall_speculator(); true)

@test repr(all_modules) == "all_modules::Speculator.AllModules"

# @test_warn "Compilation failed, please file a bug report in Speculator.jl for:\n" begin
#     open(tempname(); create = true) do file
#         Speculator.log_warn(Speculator.Parameters(;
#             file,
#             background_repl = false,
#             compile = true,
#             limit = 1,
#             predicate = Returns(true),
#             verbosity = warn
#         ), typeof(string), Type[])
#     end
# end

path = tempname()
f() = nothing
# @test_logs (:info, r"compile: .*f\(\)") speculate(f; path, verbosity = compile)
# @test_logs (:info, r"skip: .*f\(\)") speculate(f; path, verbosity = skip)

@test_throws ErrorException Speculator.wait_for_repl()

@testset "`speculate_repl`" begin
    is = Speculator.InputSpeculator(Returns(true), ())
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

    _is = Speculator.InputSpeculator(Base.isexported, (
        background = true,
        compile = false,
        limit = 8,
        path = tempname(),
        verbosity = compile ∪ review
    ))
    _x = Base.remove_linenums!(_is(:(g() = true)))
    _lines = split(string(_x), '\n')

    _b = false
    redirect_stderr(() -> _b = invokelatest(eval(_x)), devnull)
    @test _b

    for (line, regex) in zip(_lines, [
        r"begin",
        r" {4}var\"##\d+\" = \(g\(\) = begin",
        r" {16}true",
        r" {12}end\)",
        r" {4}\(Speculator.speculate\)\(Base\.isexported, var\"##\d+\"; \(background = true, compile = false, limit = 8, path = \".*\", verbosity = compile ∪ review\)\.\.\.\)",
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
    r"Generated (\d+) compilable signatures from (\d+)", read(pipe, String)
    close(pipe[2])
    parse.(Int, match(
        r"Generated (\d+) compilable signatures from (\d+)", read(pipe, String)
    ).captures)
end
count_methods(value; parameters...) = count_methods(
    Speculator.default_predicate, value;
parameters...)

speculator_count = count_methods(all_modules)[2]
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

path = tempname()
rm(path; force = true)
s = "Skipping speculation because it is not being ran during precompilation, an interactive session, or to save compilation directives"
@test_warn "$s" speculate(X; path, compile = false)
@test !isfile(path)
speculate(X; path)
@test isfile(path)

path = tempname()
@test_nowarn speculate(all_modules; path)
@test_broken (include(path); true)
# include(x -> :(@test $x), path)

@test issorted(map(limit -> count_methods(all_modules; limit)[2], 1:4))

@test count_methods(Returns(false), all_modules)[1] == 0
@test count_methods(Returns(false), ::String -> nothing)[1] == 0

abstract type A end
struct B <: A end
struct C <: A end

h(::A) = nothing

@test count_methods((_, n) -> n != :A, h) == [0, 1]
@test count_methods((_, n) -> n != :B, h) == [1, 1]
@test count_methods(h) == [0, 1]
@test count_methods(h; limit = 2) == [2, 1]

# speculate(Base)
# count precompiled + skipped
# speculate(Base)
# test that 0 were compiled and total number were skipped

#=
julia> (::String)() = nothing;

julia> speculate(""; verbosity = skip)
[ Info: Skipped `(::String)()`

julia> speculate(String; verbosity = skip)
[ Info: Skipped `String(::Vector{UInt8})`
...

julia> speculate(string; verbosity = skip)
[ Info: Skipped `string(::Base.UUID)`
...
=#

# `include("scripts/trial.jl")`

end # module
