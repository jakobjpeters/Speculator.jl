
module Speculator

# BUG: `speculate(-; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`
# TODO: `methodswith`, `isexported`, `ispublic`, `strict` targets
# TODO: tutorial to create a system image?
# TODO: seperate internal internal and external ignore
# TODO: document and skip methods that are already specialized

import Base: eltype, firstindex, getindex, iterate, lastindex, length, mul_with_overflow, show
using Base:
    Threads.@spawn, active_project, active_repl, isvarargtype,
    loaded_modules_array, Iterators.product, uniontypes
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
    abstract_methods, abstract_subtypes, all_names, callable_objects, debug, generate,
    method_types, review, union_all_caches, union_types, warn, imported_names,
    install_speculate_mode, speculate

(@ccall jl_generating_output()::Cint) == 1 &&
    speculate(Speculator; ignore = [default_ignore, default_maximum_methods, default_target],
        target = abstract_methods | abstract_subtypes | all_names | callable_objects | union_types)

end # Speculator
