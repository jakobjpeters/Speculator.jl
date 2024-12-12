
@flag(Target,
    abstract_methods, abstract_subtypes, all_names, any_subtypes, callable_objects,
    function_subtypes, imported_names, method_types, union_all_caches, union_types
)

@doc """
    Target

A flag that determines ... during [`speculate`](@ref).

The base elements are ... .
Elements may be combined using `|`.

# Interface

- `|(::Target,\u00A0::Target)`
- `in(::Target,\u00A0::Target)`
- `show(::IO,\u00A0::Target)`

# Examples

```jldoctest
```
""" Target
