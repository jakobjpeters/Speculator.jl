
module Benchmarks

using Base: loaded_modules_array, isvarargtype
using BenchmarkTools: @benchmark
using MethodAnalysis: visit
using PrecompileSignatures: Config, precompilables
using Speculator: all_modules, review, silent, initialize_parameters, is_subset

const config = Config(; split_unions = false, type_conversions = Dict{DataType, DataType}())
const loaded_modules = loaded_modules_array()

is_concrete_method(m::Method) = parentmodule(m) != Core && is_concrete_signature(m, m.sig)
is_concrete_method(@nospecialize x) = false

is_concrete_signature(m::Method, signature::DataType) = !(Tuple <: signature) && begin
    types = signature.types[2:end]
    isempty(types) || !isvarargtype(last(types)) && all(eachindex(types)) do i
        isconcretetype(types[i]) || is_subset(1, m.nospecialize >> (i - 1))
    end
end
is_concrete_signature(_, _) = false

function method_analysis()
    count = 0
    visit(x -> (count += is_concrete_method(x); true))
    count
end

precompile_signatures() = length(precompilables(loaded_modules, config))

function show_benchmark(f)
    show(stdout, MIME"text/plain"(), @benchmark $f())
    println()
end

speculator(verbosity) = initialize_parameters(all_modules, "", false;
    verbosity, dry = true, limit = 1, predicate = Returns(true), background_repl = false
)

@info "Searching for all methods with concrete signatures"

@info "Speculator.jl"
speculator(review)
show_benchmark(() -> speculator(silent))

@info "PrecompileSignatures.jl"
@show precompile_signatures()
show_benchmark(precompile_signatures)

@info "MethodAnalysis.jl"
@show method_analysis()
show_benchmark(method_analysis)

end # Benchmarks
