
@flag(Target,
    abstract_methods, abstract_subtypes, all_names, callable_objects, imported_names,
    instance_types, method_types, tuple_types, type_caches, union_all_types, union_types
)

@doc """
    Target

A flag that specifies what methods to precompile within [`speculate`](@ref).

The base flags are [`abstract_methods`](@ref), [`abstract_subtypes`](@ref),
[`all_names`](@ref), [`callable_objects`](@ref), [`instance_types`](@ref),
[`imported_names`](@ref), [`methods_types`](@ref), [`tuple_types`](@ref),
[`type_caches`], [`union_all_types`](@ref), and [`union_types`](@ref).

!!! warning
    Some combinations may result in an exponentially larger precompilation workload.

# Interface

- `|(::Target,\u00A0::Target)`
    - Combine the targets such that each satisfies `issubset` with the resulting target.
- `issubset(::Target,\u00A0::Target)`
    - Check whether each flag of the first target is a flag of the second target.
- `show(::IO,\u00A0::Target)`

# Examples

```jldoctest
julia> abstract_methods
abstract_methods::Target

julia> abstract_subtypes | all_names
(abstract_subtypes | all_names)::Target

julia> abstract_subtypes ⊆ abstract_subtypes | all_names
true

julia> abstract_subtypes ⊆ callable_objects
false
```
""" Target

@doc """
    abstract_methods

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref) will use
the cartesian product of concrete types of each method parameter in the precompilation workload.

Requires at least one of [`abstract_subtypes`](@ref), [`any_subtypes`](@ref),
[`function_subtypes`](@ref), [`type_caches`](@ref), or [`union_types`](@ref).

# Examples

```jldoctest
julia> abstract_methods
abstract_methods::Target
```
""" abstract_methods

@doc """
    abstract_subtypes

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref) will use
the subtypes of abstract types that are not `Function` and `Any` in the precompilation workload.

# Examples

```jldoctest
julia> abstract_subtypes
abstract_subtypes::Target
```
""" abstract_subtypes

@doc """
    all_names

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use `names(::Module; all = true)` in the precompilation workload.

# Examples

```jldoctest
julia> all_names
all_names::Target
```
""" all_names

@doc """
    callable_objects

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use `methods` for values in the precompilation workload.

# Examples

```jldoctest
julia> callable_objects
callable_objects::Target
```
""" callable_objects

@doc """
    imported_names

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use `names(::Module; imported = true)` in the precompilation workload.

# Examples

```jldoctest
julia> imported_names
imported_names::Target
```
""" imported_names

@doc """
    instance_types

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use the instance of each `DataType` in the precompilation workload.

# Examples

```jldoctest
julia> instance_types
instance_types::Target
```
""" instance_types

@doc """
    method_types

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use the types of the method signature in the precompilation workload.

# Examples

```jldoctest
julia> method_types
method_types::Target
```
""" method_types

@doc """
    tuple_types

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will ... .

# Examples

```jldoctest
julia> type_caches
type_caches::Target
```
""" tuple_types

@doc """
    type_caches

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use a cache of previously instantiated types in the precompilation workload.

# Examples

```jldoctest
julia> type_caches
type_caches::Target
```
""" type_caches

@doc """
    union_types

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will unwrap and use each `UnionAll` in the precompilation workload.

# Examples

```jldoctest
julia> union_types
union_types::Target
```
""" union_all_types

@doc """
    union_types

A flag of [`Target`](@ref) which specifies that [`speculate`](@ref)
will use each instance of a `Union` in the precompilation workload.

# Examples

```jldoctest
julia> union_types
union_types::Target
```
""" union_types
