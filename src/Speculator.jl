
module Speculator

#=
TODO: plot number of methods vs `limit` vs time
TODO: tutorial to create a system image?
TODO: benchmark with `PrecompileSignatures.jl` and `MethodAnalysis.jl`:
    - `speculate(all_modules; dry = true)`
    - `length(PrecompileSignatures.precompilables(Base.loaded_modules_array()))`
TODO: does `f(; (@nospecialize xs...))` work?
TODO: does `f(@nospecialize _)` work?
TODO: remove closures, because they can't be precompiled?
TODO: check this package works in notebooks
TODO: rename `dry`?
TODO: wait for a background call to `speculate` to finish before starting another?
TODO: document that some methods aren't skipped
    `f(::String)`, `f(::Union{String, Symbol})`, `speculate(f; verbosity = debug)`
TODO: remove dependency on InteractiveUtils.jl
TODO:
    https://github.com/JuliaLang/julia/issues/28808
    https://github.com/JuliaLang/julia/issues/52677
    https://github.com/JuliaLang/julia/issues/39902
=#

import Base:
    eltype, intersect, isdisjoint, isempty, issetequal,
    issubset, iterate, length, setdiff, show, symdiff, union
using Base:
    Threads, IdSet,
    checked_mul, isdeprecated, issingletontype, isvarargtype, loaded_modules_array,
    mul_with_overflow, specializations, typename, uniontypes, unsorted_names, unwrap_unionall
using .Threads: @spawn
using Core: Builtin, TypeofBottom, Typeof
using InteractiveUtils: subtypes

include("cartesian_products.jl")
include("all_modules.jl")
include("verbosities.jl")
include("utilities.jl")
include("speculate.jl")
include("input_speculators.jl")

export
    AllModules, Verbosity,
    all_modules, debug, review, silent, warn, install_speculator, speculate, uninstall_speculator

speculate(Speculator; limit = 4)

end # Speculator
