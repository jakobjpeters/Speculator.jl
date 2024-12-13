
module Speculator

# BUG: `speculate(Base; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`

import Base: eltype, firstindex, getindex, iterate, lastindex, length, show
using Base: Threads.@spawn, active_project, active_repl, Iterators.product, uniontypes
using InteractiveUtils: subtypes
using Serialization: serialize
using Statistics: mean, median
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

include("utilities.jl")
include("targets.jl")
include("verbosities.jl")
include("speculation_benchmarks.jl")
include("speculate.jl")
include("install_speculate_mode.jl")

export SpeculationBenchmark, Target, Verbosity,
    abstract_methods, abstract_subtypes, all_names, any_subtypes, callable_objects,
    debug, function_subtypes, review, union_types, warn, imported_names,
    install_speculate_mode, method_types, speculate, union_all_caches

speculate(Speculator;
    target = abstract_methods | abstract_subtypes | all_names | callable_objects | union_types)

end # Speculator
