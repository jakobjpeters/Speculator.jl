
using MethodAnalysis, PrecompileSignatures, Speculator, Test

function count_methods(predicate, value; parameters...)
    path = tempname()
    speculate(predicate, value; path, parameters...)
    length(readlines(path))
end
count_methods(value; parameters...) = count_methods(
    Speculator.default_predicate,
    value;
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
@test method_analysis_count < speculator_count
@test precompile_signatures_count < speculator_count

module X end
path = "precompile.jl"
rm(path; force = true)
speculate(X; path, dry = true)
@test !isfile(path)
speculate(X; path)
@test isfile(path)

@test_nowarn speculate(Base; dry = true)

path = tempname()
speculate(Base; path)
@test_broken (include(path); true)
# include(x -> :(@test $x), path)

@test issorted(map(limit -> count_methods(Base; limit), 1:4))

@test count_methods(Returns(false)) == 0
@test count_methods(Returns(false), () -> nothing) == 1

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
