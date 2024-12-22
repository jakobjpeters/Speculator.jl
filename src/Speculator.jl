
module Speculator

#=
BUG: `speculate_repl(; verbosity = review)` fails to handle the terminal text sometimes
TODO: plot number of methods vs `limit`
TODO: rename `speculate_repl` to `speculate_interactive`?
TODO: tutorial to create a system image?
TODO: document skipping methods that are already specialized
TODO: improve the `review` log
TODO: benchmark with `PrecompileSignatures.jl` and `MethodAnalysis.jl`:
    - `speculate(Base; dry = true)`
    - `length(PrecompileSignatures.precompilables(Base))`
TODO: document time to search for every possible method:
    `speculate(Base; verbosity = review)`
TODO: figure out how `julia --trace-compile=precompile.jl` works
TODO: does `f(; (@nospecialize xs...))` work?
TODO: does `f(@nospecialize _)` work?
TODO: remove closures, because they are not precompilable
=#

import Base: eltype, firstindex, getindex, issubset, iterate, lastindex, length, show
using Base:
    Threads.@spawn, active_project, isvarargtype, mul_with_overflow,
    Iterators.product, specializations, uniontypes, unsorted_names
using InteractiveUtils: subtypes
using Serialization: serialize
using Statistics: mean, median
using REPL: LineEdit.refresh_line

for path in [
    "verbosities.jl",
    "utilities.jl",
    "speculation_benchmarks.jl",
    "speculate.jl",
    "speculate_repl.jl"
]
    include(path)
end

export SpeculationBenchmark, Verbosity, debug, review, silent, warn, speculate_repl, speculate

speculate(Speculator; limit = 4)

end # Speculator
