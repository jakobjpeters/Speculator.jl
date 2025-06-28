
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
to search for compilable methods from every loaded module.

# Examples

```jldoctest
julia> all_modules
all_modules::AllModules

julia> speculate(all_modules; compile = false, verbosity = review)
```
"""
const all_modules = AllModules()

show(io::IO, ::AllModules) = print(io, "all_modules::", AllModules)
