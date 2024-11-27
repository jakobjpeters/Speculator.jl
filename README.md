
# Speculator.jl

Speculator.jl is a tool for automatic precompilation.
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

julia> speculate!([Base]; all = false, log = false, recursive = false)
```

## Features

- Automatic precompilation of concretely typed methods from the given modules
    - Can be used as a precompilation workload

### Planned

- Multi-threading
- Abstractly typed methods
- Support for Revise.jl
- Custom REPL mode
