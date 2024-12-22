
module Speculator

#=
BUG: `speculate_repl(; verbosity = review)` fails to handle the terminal text sometimes
TODO: plot number of methods vs `maximum_methods`
TODO: rename `maximum_methods`
TODO: tutorial to create a system image?
TODO: `strict` to only use values defined in current or parent module
TODO: seperate internal internal and external ignore
TODO: document skipping methods that are already specialized
TODO: improve the `review` log
TODO: benchmark with `PrecompileSignatures.jl`:
    - `speculate(; dry = true)`
    - `length(PrecompileSignatures.precompilables(Base.loaded_modules_array()))`
TODO: document time to search for every possible method:
    `speculate(; target = all_names | abstract_methods, verbosity = review)`
TODO: `predicate = Returns(true)` instead of `Target`
    - called as `predicate(::Module, ::Any)`
    - document useful predicates:
        - types and values
        - `ispublic(::Module, ::Any)`
        - `isconcretetype`
        - `isexported(::Module, ::Any)`
    - the module the value was found in is passed to the predicate
    - delete `ignored`
    - test and document that `predicate = x -> !(x isa Method)` does nothing
    - direct input is searched by default because there isn't a module to pass to the predicate
    - automatically make `@nospecialize`?
        - foreach(method -> (method.nospecialize |= 2), methods(predicate))
    - only search things that increase the maximum number of found methods?
    - `verbosity = silent::Verbosity`
TODO: figure out how `julia --trace-compile=precompile.jl` works
TODO: does `f(; (@nospecialize xs...))` work?
TODO: does `f(@nospecialize _)` work?
=#

import Base: eltype, firstindex, getindex, issubset, iterate, lastindex, length, show
using Base:
    MethodList, RefValue, Threads.@spawn,
    active_project, add_with_overflow, issubset, isvarargtype, loaded_modules_array,
    mul_with_overflow, Iterators.product, specializations, uniontypes, unwrap_unionall
using Core: MethodInstance, Typeof
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

export
    SpeculationBenchmark, Target, Verbosity,
    debug, review, silent, speculate_repl, speculate, warn

speculate(Speculator; limit = 4)

end # Speculator
