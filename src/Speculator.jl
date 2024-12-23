
module Speculator

#=
BUG: `speculate_repl(; verbosity = review)` fails to handle the terminal text sometimes
BUG: catch possible error in `scripts/trials.jl` with `add`
TODO: after registering, mention PrecompileSignatures.jl and Speculator.jl
    https://github.com/JuliaLang/PrecompileTools.jl/issues/28
TODO: plot number of methods vs `limit`
TODO: rename `speculate_repl` to `speculate_interactive`?
TODO: tutorial to create a system image?
TODO: document skipping methods that are already specialized
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
TODO: make `Verbosity` an `AbstractSet`?
=#

import Base: eltype, firstindex, getindex, issubset, iterate, lastindex, length, show
using Base:
    Iterators, Threads, IdSet, active_project, isvarargtype,
    mul_with_overflow, specializations, uniontypes, unsorted_names
using .Iterators: product
using .Threads: @spawn
using Core: TypeofBottom, Typeof
using InteractiveUtils: subtypes
using Pkg: activate, add, develop, instantiate, resolve
using REPL: LineEdit.refresh_line
using Serialization: serialize

include("verbosities.jl")
include("utilities.jl")
include("speculation_benchmarks.jl")
include("speculate.jl")
include("speculate_repl.jl")

export SpeculationBenchmark, Verbosity, debug, review, silent, warn, speculate_repl, speculate

speculate(Speculator; limit = 4)

end # Speculator
