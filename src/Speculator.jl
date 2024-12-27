
module Speculator

#=
TODO: after registering, mention PrecompileSignatures.jl and Speculator.jl?
    https://github.com/JuliaLang/PrecompileTools.jl/issues/28
TODO: plot number of methods vs `limit` vs time
TODO: tutorial to create a system image?
TODO: benchmark with `PrecompileSignatures.jl` and `MethodAnalysis.jl`:
    - `speculate(all_modules; dry = true)`
    - `length(PrecompileSignatures.precompilables(Base.loaded_modules_array()))`
TODO: benchmark time to search for every possible method:
    `speculate(all_modules; verbosity = review)`
TODO: figure out how `julia --trace-compile=precompile.jl` works
TODO: does `f(; (@nospecialize xs...))` work?
TODO: does `f(@nospecialize _)` work?
TODO: remove closures, because they can't be precompiled?
TODO: check this package works in notebooks
TODO: rename `dry`?
TODO: wait for a background call to `speculate` to finish before starting another?
TODO: document that some methods aren't skipped
    `f(::String)`, `f(::Union{String, Symbol})`, `speculate(f; verbosity = debug)`
TODO: implement `Base.symdiff(::Verbosity, ::Verbosity...)`
=#

import Base:
    eltype, firstindex, getindex, isdisjoint, isempty,
    issetequal, issubset, iterate, lastindex, length, show
using Base:
    Threads, IdSet, active_project, isdeprecated, issingletontype, isvarargtype,
    loaded_modules_array, mul_with_overflow, specializations, uniontypes, unsorted_names
using .Threads: @spawn
using Core: TypeofBottom, Typeof
using InteractiveUtils: subtypes
using Serialization: serialize

include("cartesian_products.jl")
include("all_modules.jl")
include("verbosities.jl")
include("utilities.jl")
include("speculation_benchmarks.jl")
include("speculate.jl")
include("input_speculators.jl")

export
    AllModules, SpeculationBenchmark, Verbosity,
    all_modules, debug, review, silent, warn, install_speculator, speculate, uninstall_speculator

speculate(Speculator; limit = 4)

end # Speculator
