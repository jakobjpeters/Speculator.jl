
module Speculator

# BUG: `speculate(-; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`
# TODO: `methodswith`
# TODO: tutorial to create a system image?
# TODO: seperate internal internal and external ignore

import Base: eltype, firstindex, getindex, iterate, lastindex, length, show
using Base: Threads.@spawn, active_project, active_repl, Iterators.product, uniontypes
using InteractiveUtils: subtypes
using Serialization: serialize
using Statistics: mean, median
using REPL: LineEdit.refresh_line
using ReplMaker: complete_julia, initrepl

include("flags/flags.jl")
include("utilities.jl")
include("speculation_benchmarks.jl")
include("speculate.jl")
include("install_speculate_mode.jl")

export SpeculationBenchmark, Target, Verbosity,
    abstract_methods, abstract_subtypes, all_names, callable_objects,
    debug, review, union_types, warn, imported_names,
    install_speculate_mode, method_types, speculate, union_all_caches

speculate(Speculator; ignore = [default_maximum_methods, default_target],
    target = abstract_methods | abstract_subtypes | all_names | callable_objects | union_types)

end # Speculator
