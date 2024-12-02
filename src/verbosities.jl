
"""
    Verbosity

Flags that determine what logging statements are shown during [`speculate`](@ref).

The base flags are [`none`](@ref), [`warn`](@ref), [`review`](@ref), and [`debug`](@ref).
Elements may be combined using `|`.

# Interface

- `|(::Verbosity,\u00A0::Verbosity)`
- `show(::IO,\u00A0::MIME"text/plain",\u00A0::Verbosity)`

# Examples

```jldoctest
julia> none | warn
warn::Verbsosity

julia> review | debug
(review | debug)::Verbosity
```
"""
struct Verbosity
    value::UInt8

    verbosity(x) = new(x)

    @eval begin
        const none = $verbosity(0)
        const verbosities = Pair{Verbosity, Symbol}[]

        (v::Verbosity | _v::Verbosity) = $verbosity(v.value | _v.value)
    end

    for (i, name) in enumerate([:debug, :review, :warn])
        @eval begin
            const $name = $verbosity($(2 ^ (i - 1)))
            push!(verbosities, $name => $(QuoteNode(name)))
        end
    end
end

@doc """
    none

An element of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show no logging statements.

# Examples

```jldoctest
julia> none
none::Verbosity
```
""" none

@doc """
    warn

An element of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show warnings for failed calls to `precompile`.

# Examples

```jldoctest
julia> warn
warn::Verbosity
```
""" warn

@doc """
    review

An element of [`Verbosity`](@ref) which specifies that [`speculate`](@ref)
should show the total number of values that have been speculated.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" review

@doc """
    debug

An element of [`Verbosity`](@ref) which specifies that
[`speculate`](@ref) should show each successful call to `precompile`.

# Examples

```jldoctest
julia> debug
debug::Verbosity
```
""" debug

function in(v::Verbosity, _v::Verbosity)
    value = v.value
    value == (value & _v.value)
end

function show(io::IO, v::Verbosity)
    flags = Symbol[]

    for (_v, name) in verbosities
        _v in v && push!(flags, name)
    end

    n = length(flags)

    if n == 0 print(io, "none")
    elseif n == 1 print(io, only(flags))
    else
        print(io, '(')
        join(io, flags, " | ")
        print(io, ')')
    end

    print(io, "::", Verbosity)
end
