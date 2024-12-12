
"""
    Target

A flag that determines ... during [`speculate`](@ref).

The base elements are ... .
Elements may be combined using `|`.

# Interface

- `|(::Target,\u00A0::Target)`
- `show(::IO,\u00A0::MIME"text/plain",\u00A0::Target)`

# Examples

```jldoctest
```
"""
struct Target
    value::UInt8

    target(x) = new(x)

    @eval begin
        const functions = $target(0)
        const targets = Pair{Target, Symbol}[]
        (t::Target | _t::Target) = $target(t.value | _t.value)
    end

    for (i, name) in enumerate([
        :abstract_methods, :abstract_types, :all_names, :callable_objects,
        :imported_names, :method_types, :union_all_caches, :union_types
    ])
        @eval begin
            const $name = $target($(2 ^ (i - 1)))
            push!(targets, $name => $(QuoteNode(name)))
        end
    end
end

function in(t::Target, _t::Target)
    value = t.value
    value == (value & _t.value)
end

function show(io::IO, t::Target)
    flags = Symbol[:functions]

    for (_t, name) in targets
        _t in t && push!(flags, name)
    end

    if length(flags) == 1 print(io, only(flags))
    else
        print(io, '(')
        join(io, flags, " | ")
        print(io, ')')
    end

    print(io, "::", Target)
end
