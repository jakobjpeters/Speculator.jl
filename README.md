
# Speculator.jl

## Introduction

Speculator.jl is a tool to reduce latency by generating and running precompilation workloads.

Code needs to be compiled, either upon the installation of a package or as needed during runtime.
In the former case, this can be used in a package as a supplement or alternative to
[PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl).
In the latter case, it can be used in a `startup.jl` file or interactively in the REPL.

Credit to [Cameron Pfiffer](https://github.com/cpfiffer) for the initial idea.

## Usage

### Installation

```julia-repl
julia> using Pkg: add

julia> add(; url = "https://github.com/jakobjpeters/Speculator.jl")
```

### Showcase

```julia-repl
julia> using Speculator

julia> speculate(Iterators;
           verbosity = debug | review,
           target = method_types | union_types
       )
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

julia> SpeculationBenchmark(Plots, 8)
Precompilation benchmark with `8` samples:
  Mean:    `5.113`
  Median:  `5.1546`
  Minimum: `4.724`
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

- Run precompilation workloads for modules, functions, and types.
    - Configurable to run in the background,
        show logging statements, and select precompilation targets.
- Custom REPL mode that runs a workload for every input.
- Estimate the compilation time saved by a workload.

### Planned

- Disable during development using Preferences.jl?
- Support for Revise.jl?
- Threaded workloads?

## Similar Packages

- [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl)
- [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl)
    - [SnoopCompileCore.jl](https://github.com/timholy/SnoopCompile.jl/tree/master/SnoopCompileCore)
