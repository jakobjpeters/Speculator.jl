
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

## Features

- Automatically generate a compilation workload from modules and callable objects.
    - Configurable to run in the background, select precompilation targets, and write to a file.
    - Can be ran in the REPL after each input.

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
- [CompileTraces.jl](https://github.com/serenity4/CompileTraces.jl)
- [JET.jl](https://github.com/aviatesk/JET.jl)
- [MethodAnalysis.jl](https://github.com/timholy/MethodAnalysis.jl)
- [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl)
- [PkgCacheInspector.jl](https://github.com/timholy/PkgCacheInspector.jl)
- [PrecompileSignatures.jl](https://github.com/rikhuijzer/PrecompileSignatures.jl)
- [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl)
- [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl)
    - [SnoopCompileCore.jl](https://github.com/timholy/SnoopCompile.jl/tree/master/SnoopCompileCore)
