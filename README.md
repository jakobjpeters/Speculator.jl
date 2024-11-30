
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

## Case Study

Consider Plots.jl, the go-to example when discussing latency in Julia
and the substantial improvements made to the time-to-first-X problem.

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
julia> @elapsed speculate(Plots; background = false)
10.865878121
```

This information alone doesn't say much, since it measures both time spent
searching for methods to precompile and the time precompiling itself.
Since the workload is now compiled by Julia, emptying the cache and running it again
provides an estimate of the time spent outside of compilation.

```julia-repl
julia> empty_cache()
[ Info: The `speculate` cache has been emptied

julia> @elapsed speculate(Plots; background = false)
0.54081279
```

This means that the workload runs approximately 10 seconds of compilation.
Further, since Speculator.jl currently only compiles methods with concrete type signatures,
the methods that were compiled are guaranteed to be either used by Plots.jl or dead code.
Including this precompilation workload in Plots.jl or running it in the background of
an interactive session could save up to 10 seconds of compilation in each session.

## Usage

### Installation

```julia-repl
julia> using Pkg: add

julia> add(; url = "github.com/jakobjpeters/Speculator.jl")
```

### Usage

```julia-repl
julia> using Speculator

julia> speculate(Speculator)
```

## Features

- Run precompilation workloads for modules, functions, and types.
- Configuration to run in the background and show logging statements.
- Custom REPL mode that runs a workload for every input.

### Planned

- Disable during development using Preferences.jl
- Abstractly typed methods
- Support for Revise.jl
- Threaded workloads
