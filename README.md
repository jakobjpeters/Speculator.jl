
# Speculator.jl

## Introduction

Speculator.jl is a tool to reduce latency by generating and running precompilation workloads.

Code needs to be compiled, either upon the installation of a package or as needed during runtime.
In the former case, this can be used in a package as a supplement or alternative to
[PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl).
In the latter case, it can be used in a `startup.jl` file or interactively in the REPL.

Credit to [Cameron Pfiffer](https://github.com/cpfiffer) for the initial idea.
The preexisting package
[PrecompileSignatures.jl](https://github.com/rikhuijzer/PrecompileSignatures.jl)
implements similar functionality, notably that
`PrecompileSignatures.@precompile_signatures ::Module`
is roughly equivalent to
`Speculator.speculate(::Module; target = abstract_subtypes | all_names | union_types)`.

## Usage

### Installation

```julia-repl
julia> using Pkg: add

julia> add(; url = "https://github.com/jakobjpeters/Speculator.jl")
```

### Showcase

```julia-repl
julia> using Speculator

julia> speculate_repl(;
           target = all_names,
           verbosity = debug
       )
[ Info: The REPL will call `speculate` on each input

julia> module Showcase
           export g

           f(::Int) = nothing
           g(::Union{String, Symbol}) = nothing
       end
Main.Showcase
[ Info: Precompiled `Main.Showcase.g(::Int64)

julia> speculate(Showcase;
           target = abstract_methods | union_types,
           verbosity = debug
       )
[ Info: Precompiled `Main.Showcase.g(::Symbol)`
[ Info: Precompiled `Main.Showcase.g(::String)`
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

- Automatically generate a precompilation workload from
    modules, functions, types, and callable objects.
    - Configurable to run in the background, select precompilation targets, and write to a file.
- Estimate the compilation time saved by a workload.
- Custom REPL mode that runs a workload for every input.

### Planned

- Disable during development using Preferences.jl?
- Support for Revise.jl?
- Threaded workloads?

## Similar Packages

- [PrecompileSignatures.jl](https://github.com/rikhuijzer/PrecompileSignatures.jl)
- [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl)
- [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl)
    - [SnoopCompileCore.jl](https://github.com/timholy/SnoopCompile.jl/tree/master/SnoopCompileCore)
