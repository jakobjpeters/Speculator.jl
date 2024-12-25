
# Speculator.jl

## Introduction

Speculator.jl is a tool to reduce latency by automatically
generating and running compilation workloads.

Code needs to be compiled, either upon the installation of a package or as needed during runtime.
In the former case, this can be used in a package as a supplement or alternative to
[PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl).
In the latter case, it can be used in a `startup.jl` file or interactively in the REPL.

## Usage

### Installation

```julia-repl
julia> using Pkg: add

julia> add(; url = "https://github.com/jakobjpeters/Speculator.jl")

julia> using Speculator
```

### Showcase

```julia-repl
julia> module Showcase
           export g, h

           f() = nothing
           g(::Int) = nothing
           h(::Union{String, Symbol}) = nothing
       end;

julia> speculate(Showcase; verbosity = debug)
[ Info: Compiled `Main.Showcase.g(::Int)`
[ Info: Compiled `Main.Showcase.f()`

julia> speculate(Base.isexported, Showcase; verbosity = debug)
[ Info: Skipped `Main.Showcase.g(::Int)`

julia> speculate(Showcase.h; limit = 2, verbosity = debug)
[ Info: Compiled `Main.Showcase.h(::String)`
[ Info: Compiled `Main.Showcase.h(::Symbol)`

julia> speculate_repl(; limit = 4, verbosity = debug)
[ Info: The REPL will call `speculate` with each input

julia> i(::Union{String, Symbol}, ::Union{String, Symbol}) = nothing;
[ Info: Compiled `Main.i(::Symbol, ::Symbol)`
[ Info: Compiled `Main.i(::String, ::Symbol)`
[ Info: Compiled `Main.i(::Symbol, ::String)`
[ Info: Compiled `Main.i(::String, ::String)`
```

## Case Study

Consider [Plots.jl](https://github.com/JuliaPlots/Plots.jl), the go-to example when discussing
latency in Julia and the substantial improvements made to the time-to-first-X problem.

```julia-repl
julia> using Plots

julia> @elapsed plot(1)
0.106041791
```

This call has very low latency, demonstrating that code
for core functions has been effectively precompiled.
However, it is challenging to manually identify an exhaustive set of methods to precompile.
Speculator.jl can do this automatically.

```julia-repl
julia> @elapsed using Speculator
0.040658097

julia> SpeculationBenchmark(Plots)
Precompilation benchmark with `8` samples:
  Mean:    `5.1130`
  Median:  `5.1546`
  Minimum: `4.7240`
  Maximum: `5.5401`
```

The `SpeculationBenchmark` estimates the compilation time that `speculate` saves.
This case uses the minimum `target`, which only compiles methods of public
functions, types, and the types of values, recursively for public modules.
Although there are numerous additional targets, this target only precompiles a subset
of the methods that are accessible to users as part of the Plots.jl public interface.
This can be verified using `speculate(Plots; verbosity = debug | review)`.
Therefore, including this precompilation workload in Plots.jl or running it in the background
of an interactive session can save up to five seconds of compilation time per session.
Testing and selecting additional targets can save even more time.

If instead, the Plots.jl workload did not precompile any new methods,
using Speculator.jl would not meaningfully lengthen loading time.
The package itself takes a fraction of a second to load in a package or interactive session.
Running a workload in the background also only takes a fraction of a second to initiate.
Therefore, using Speculator.jl has a high benefit to
cost ratio in terms of compilation and loading time.

## Features

- Automatically generate a compilation workload from modules and callable objects.
    - Configurable to run in the background, select precompilation targets, and write to a file.
    - Can be ran in the REPL after each input.
- Benchmark the compilation time of a workload.

### Planned

- Disable during development using Preferences.jl?
- Support for `UnionAll` types?

## Acknowledgements

Credit to [Cameron Pfiffer](https://github.com/cpfiffer) for the initial idea.

The preexisting package PrecompileSignatures.jl implements similar functionality,
notably that `PrecompileSignatures.@precompile_signatures ::Module`
is roughly equivalent to `Speculator.speculate(::Module)`.

## Similar Packages

- [Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl)
- [JET.jl](https://github.com/aviatesk/JET.jl)
- [MethodAnalysis.jl](https://github.com/timholy/MethodAnalysis.jl)
- [PkgCacheInspector.jl](https://github.com/timholy/PkgCacheInspector.jl)
- [PrecompileSignatures.jl](https://github.com/rikhuijzer/PrecompileSignatures.jl)
- [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl)
- [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl)
    - [SnoopCompileCore.jl](https://github.com/timholy/SnoopCompile.jl/tree/master/SnoopCompileCore)
