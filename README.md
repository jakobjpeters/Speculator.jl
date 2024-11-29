
# Speculator.jl

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
