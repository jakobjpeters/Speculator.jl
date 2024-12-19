
module Speculator

# BUG: `speculate(-; background = false, verbosity = warn | review, target = abstract_methods | union_all_caches)`
# TODO: `methodswith`, `isexported`, `ispublic`, `strict`, `supertypes` targets
# TODO: tutorial to create a system image?
# TODO: seperate internal internal and external ignore
# TODO: document skipping methods that are already specialized
# TODO: improve the `review` log

import Base: eltype, firstindex, getindex, iterate, lastindex, length, mul_with_overflow, show
using Base:
    MethodList, RefValue, Threads.@spawn, active_project, isvarargtype,
    loaded_modules_array, Iterators.product, specializations, uniontypes
using Core: MethodInstance, Typeof
using InteractiveUtils: subtypes
using Serialization: serialize
using Statistics: mean, median
using REPL: LineEdit.refresh_line

include("flags/flags.jl")
include("utilities.jl")
include("speculation_benchmarks.jl")
include("speculate.jl")
include("speculate_repl.jl")

export SpeculationBenchmark, Target, Verbosity,
    abstract_methods, abstract_subtypes, all_names, callable_objects, imported_names,
    instance_types, method_types, tuple_types, type_caches, union_all_types, union_types,
    debug, review, warn,
    speculate_repl, speculate

(@ccall jl_generating_output()::Cint) == 1 &&
    speculate(Speculator; ignore = [default_ignore, default_maximum_methods, default_target],
        target = abstract_methods | abstract_subtypes | all_names | union_types)

end # Speculator
