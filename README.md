
# Speculator.jl

## Introduction

Speculator.jl is a tool to reduce latency by generating and running precompilation workloads.

These workloads compile methods with concrete type
signatures and are run in a background thread by default.
However, they do not yet handle abstractly typed methods,
method invalidations, and dynamic dispatch.

Code needs to be compiled, either upon installation of a package or as needed during runtime.
In the former case, this can be used in a package as a supplement or alternative to
[PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl).
In the latter case, it can be used in a `startup.jl` or interactively in the REPL.

Credit to [Cameron Pfiffer](https://github.com/cpfiffer) for the initial idea.

## Usage

### Installation

```julia-repl
julia> using Pkg: add

julia> add(; url = "github.com/jakobjpeters/Speculator.jl")
```

### Showcase

```julia-repl
julia> using Speculator

julia> speculate(Base; verbosity = debug)
```

## Case Study

Consider [Plots.jl](https://github.com/JuliaPlots/Plots.jl), the go-to example when discussing
latency in Julia and the substantial improvements made to the time-to-first-X problem.

```julia-repl
julia> using Plots

julia> @elapsed plot(1)
0.096673055
```

This call has very low latency, demonstrating that code
for core functions has been effectively precompiled.
However, it is challenging to manually identify an exhaustive set of methods to precompile.
Speculator.jl can do this automatically.

```julia-repl
julia> @elapsed using Speculator
0.024472137

julia> @elapsed speculate(Plots; background = false)
10.865878121

julia> @elapsed speculate(Plots; background = false)
0.54081279
```

The initial call to `speculate` measures both time spent searching
for methods to precompile and the precompilation time itself.
Since the workload has been precompiled, the subsequent call provides
an estimate of the time spent searching for methods to precompile.
The difference is then an estimate of the compilation time,
which is approximately 10 seconds.

Since Speculator.jl only compiles methods with concrete type signatures, the
methods compiled by this workload are likely to be either called within Plots.jl or dead code.
Therefore, including this precompilation workload in Plots.jl or running it in the background
of an interactive session could save up to 10 seconds of compilation time per session.

If instead, the Plots.jl workload did not compile any new methods,
using Speculator.jl would not meaningfully lengthen loading time.
The package itself takes a fraction of a second to load in a package or interactive session.
Running this workload in Plots.jl would only add a half of a second to
precompilation time upon installation; running a workload in the background
of an interactive session would only take a fraction of a second to initiate.
Therefore, using Speculator.jl has a high benefit to
cost ratio in terms of compilation and loading time.

## Features

- Run precompilation workloads for modules, functions, and types.
- Configuration to run in the background and show logging statements.
- Custom REPL mode that runs a workload for every input.

### Planned

- Disable during development using Preferences.jl
- Abstractly typed methods?
- Support for Revise.jl
- Threaded workloads
