
"""
    AllModules

A singleton type whose only value is [`all_modules`](@ref).

# Interface

- `show(::IO, ::AllModules)`

# Examples

```jldoctest
julia> AllModules
AllModules
```
"""
struct AllModules end

"""
    all_modules::AllModules

The singleton constant of [`AllModules`](@ref) used with [`speculate`](@ref)
to generate a compilation workload using all loaded modules.

# Examples

```jldoctest
julia> all_modules
all_modules::AllModules
```
"""
const all_modules = AllModules()

show(io::IO, ::AllModules) = print(io, "all_modules::", AllModules)
