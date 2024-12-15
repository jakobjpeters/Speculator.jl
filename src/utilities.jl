
const default_ignore = []

const default_max_methods = 2 ^ 8

const default_target = nothing

macro flag(type, names...)
    name = string(type)
    constructor_name, type_name = Symbol(lowercasefirst(name)), Symbol(name)
    values_names = map(((i, name),) -> 2 ^ (i - 1) => name, enumerate(names))

    esc(quote
        struct $type
            value::$(Symbol(:UInt, max(8, 2 ^ Int(ceil(log(2, length(names)))))))

            global $constructor_name

            $constructor_name(x::Int) = new(x)
            $constructor_name(::Nothing) = new(0)
            $constructor_name(x::$type_name) = x

            Base.:|(f::$type_name, _f::$type_name) = new(f.value | _f.value)

            is_subset(f, _f) = f == (f & _f)

            Base.issubset(f::$type_name, _f::$type_name) = is_subset(f.value, _f.value)

            function Base.show(io::IO, flag::$type_name)
                value, names = flag.value, Symbol[]

                for (_value, name) in $values_names
                    is_subset(_value, value) && push!(names, name)
                end

                n = length(names)

                if n == 0 print(io, :nothing)
                elseif n == 1 print(io, only(names))
                else
                    print(io, '(')
                    join(io, names, " | ")
                    print(io, ')')
                end

                print(io, "::", $type_name)
            end
        end

        $(map(((value, name),) -> :(const $name = $constructor_name($value)), values_names)...)
        nothing
    end)
end

function cache!(f, cache, object_id, @nospecialize x; kwargs...)
    @nospecialize
    if !(object_id in cache)
        push!(cache, object_id)
        f(x; kwargs...)
    end
end

function check_cache(x::Union{DataType, Function, Module, UnionAll, Union}; cache, kwargs...)
    @nospecialize
    cache!((x; kwargs...) -> begin
        @nospecialize
        speculate_cached(x; kwargs...)
    end, cache, objectid(x), x; cache, kwargs...)
end
function check_cache(x::T; cache, callable_cache, target, kwargs...) where T
    @nospecialize
    object_id = objectid(T)
    callable_objects ⊆ target && cache!((x; kwargs...) -> begin
        @nospecialize
        precompile_methods(x; kwargs...)
    end, callable_cache, object_id, x; cache, callable_cache, target, kwargs...)
    cache!((x; kwargs...) -> begin
        @nospecialize
        speculate_cached(x; kwargs...)
    end, cache, object_id, T; cache, callable_cache, target, kwargs...)
end

filter_same(x) = filter(subtype -> !(x <: subtype), subtypes(x))

is_not_vararg(::typeof(Vararg)) = false
is_not_vararg(_) = true

leaf_types(x::DataType, target) = abstract_subtypes ⊆ target ? filter_same(x) : []
leaf_types(x::Type{Any}, target) = any_subtypes ⊆ target ? filter_same(x) : []
leaf_types(x::Type{Function}, target) = function_subtypes ⊆ target ? subtypes(x) : []
leaf_types(x::UnionAll, target) = union_all_caches ⊆ target ? union_all_cache!([], target, x) : []
leaf_types(x::Union, target) = union_types ⊆ target ? uniontypes(x) : []

function log_repl((@nospecialize f), background)
    flag = background && isinteractive()
    flag && print(stderr, "\33[2K\r\33[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

function precompile_concrete(x, types; background, count, dry, verbosity, _...)
    @nospecialize
    if dry || precompile(x, types)
        debug ⊆ verbosity &&
            log_repl(() -> (@info "Precompiled `$(signature(x, types))`"), background)
        count[] += 1
    elseif warn ⊆ verbosity
        log_repl(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))`"), background)
    end
end

function precompile_methods(x; kwargs...)
    @nospecialize
    for method in methods(x)
        precompile_method(x, method.nospecialize, method.sig; kwargs...)
    end
end

function precompile_method(x, nospecialize, sig::DataType; max_methods, target, kwargs...)
    @nospecialize
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if abstract_methods ⊆ target
            if all(is_not_vararg, parameter_types)
                product_types = map(eachindex(parameter_types)) do i
                    branches, leaves = Type[parameter_types[i]], DataType[]
                    no_specialize = (nospecialize >> (i - 1)) & 1 == 1

                    while !isempty(branches)
                        branch = pop!(branches)

                        if isconcretetype(branch) &&
                            !any(type -> type <: branch, [DataType, UnionAll, Union])
                            push!(leaves, branch)
                            no_specialize && break
                        else append!(branches, leaf_types(branch, target))
                        end
                    end

                    leaves
                end

                (length(product_types) == 0 || prod(length, product_types) ≤ max_methods) &&
                    for concrete_types in product(product_types...)
                        precompile_concrete(x, concrete_types; kwargs...)
                    end
            end
        elseif all(isconcretetype, parameter_types)
            precompile_concrete(x, (parameter_types...,); kwargs...)
        end

        if method_types ⊆ target
            for parameter_type in parameter_types
                check_cache(parameter_type; max_methods, target, kwargs...)
            end
        end
    end
end
precompile_method(x, nospecialize, ::UnionAll; _...) = @nospecialize

function round_time(x)
    whole, fraction = split(string(max(0.0, round(x; digits = 4))), '.')
    whole * '.' * rpad(fraction, 4, '0')
end

function signature(x, types)
    @nospecialize
    signature(x) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'
end
signature(@nospecialize x::Union{Function, Type}) = repr(x)
signature(@nospecialize ::T) where T = "(::" * repr(T) * ')'

# TODO: `methodswith`
function speculate_cached(x::Function; kwargs...)
    @nospecialize
    precompile_methods(x; kwargs...)
end
function speculate_cached(x::Module; target, kwargs...)
    @nospecialize
    for name in names(x; all = all_names ⊆ target, imported = imported_names ⊆ target)
        isdefined(x, name) && check_cache(getfield(x, name); target, kwargs...)
    end
end
function speculate_cached(x::Union{DataType, UnionAll, Union}; target, kwargs...)
    @nospecialize
    precompile_methods(x; target, kwargs...)

    for type in leaf_types(x, target)
        check_cache(type; target, kwargs...)
    end
end

union_all_cache!(types, _, x::DataType) =
    append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, target, x::UnionAll) = union_all_cache!(types, target, x.body)
function union_all_cache!(types, target, x::Union)
    for type in leaf_types(x, target)
        union_all_cache!(types, target, type)
    end

    types
end
