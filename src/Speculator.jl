
module Speculator

#=
BUG: `speculate_repl(; verbosity = review)` fails to handle the terminal text sometimes
BUG: catch possible error in `scripts/trials.jl` with `add`
TODO: after registering, mention PrecompileSignatures.jl and Speculator.jl
    https://github.com/JuliaLang/PrecompileTools.jl/issues/28
TODO: plot number of methods vs `limit`
TODO: tutorial to create a system image?
TODO: benchmark with `PrecompileSignatures.jl` and `MethodAnalysis.jl`:
    - `speculate(Base; dry = true)`
    - `length(PrecompileSignatures.precompilables(Base))`
TODO: document time to search for every possible method:
    `speculate(Base; verbosity = review)`
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
TODO: try to remove `Pkg` dependency
=#

import Base:
    eltype, firstindex, getindex, isdisjoint, isempty,
    issetequal, issubset, iterate, lastindex, length, show
using Base:
    Iterators, Threads, IdSet, active_project, isvarargtype, loaded_modules_array,
    mul_with_overflow, specializations, uniontypes, unsorted_names
using .Iterators: product
using .Threads: @spawn
using Core: TypeofBottom, Typeof
using InteractiveUtils: subtypes
using Pkg: activate, add, develop, instantiate, resolve
using REPL: LineEdit.refresh_line
using Serialization: serialize

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
