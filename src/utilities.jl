
macro flag(type, names...)
    name = string(type)
    constructor_name, type_name = Symbol(lowercasefirst(name)), Symbol(name)
    values_names = map(((i, name),) -> 2 ^ (i - 1) => name, enumerate(names))

    esc(quote
        struct $type
            value::$(Symbol(:UInt, type == :verbosity ? 8 : 16))

            $constructor_name(x::Int) = new(x)
            $constructor_name(::Nothing) = new(0)
            $constructor_name(x::$type_name) = x
            global $constructor_name

            Base.:|(f::$type_name, _f::$type_name) = new(f.value | _f.value)

            _in(f, _f) = f == (f & _f)

            Base.in(f::$type_name, _f::$type_name) = _in(f.value, _f.value)

            function Base.show(io::IO, flag::$type_name)
                value, names = flag.value, Symbol[]

                for (_value, name) in $values_names
                    _in(_value, value) && push!(names, name)
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

cache!(f, cache, object_id, @nospecialize x; kwargs...) = if !(object_id in cache)
    push!(cache, object_id)
    f(x; kwargs...)
end

check_cache(x::Union{DataType, Function, Module, UnionAll, Union}; cache, kwargs...) = cache!(
    (x; kwargs...) -> speculate_cached(x; kwargs...), cache, objectid(x), x; cache, kwargs...)
function check_cache(@nospecialize x::T; cache, callable_cache, target, kwargs...) where T
    object_id = objectid(T)
    callable_objects in target && cache!((x; kwargs...) -> precompile_methods(x; kwargs...),
        callable_cache, object_id, x; cache, callable_cache, target, kwargs...)
    cache!((x; kwargs...) -> speculate_cached(x; kwargs...),
        cache, object_id, T; cache, callable_cache, target, kwargs...)
end

is_not_vararg(::typeof(Vararg)) = false
is_not_vararg(_) = true

leaf_types(x::Type{Any}, target) =
    any_subtypes in target ? filter(subtype -> !(x <: subtype), subtypes(x)) : []
leaf_types(x::Type{Function}, target) =
    function_subtypes in target ? subtypes(x) : []
leaf_types(x::DataType, target) =
    abstract_subtypes in target ? filter(subtype -> !(x <: subtype), subtypes(x)) : []
leaf_types(x::UnionAll, target) = union_all_caches in target ? union_all_cache!([], target, x) : []
leaf_types(x::Union, target) = union_types in target ? uniontypes(x) : []

function log(f, background)
    flag = background && isdefined(Base, :active_repl)
    flag && print(stderr, "\33[2K\r\33[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

precompile_concrete(x, types; background, count, verbosity, _...) =
    if precompile(x, types)
        debug in verbosity &&
            log(() -> (@info "Precompiled `$(signature(x, types))`"), background)
        count[] += 1
    elseif warn in verbosity
        log(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, types))`"), background)
    end

precompile_methods(x; kwargs...) = for method in methods(x)
    precompile_method(x, method.nospecialize, method.sig; kwargs...)
end

precompile_method(x, nospecialize, sig::DataType; target, kwargs...) =
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if abstract_methods in target
            if all(is_not_vararg, parameter_types)
                for concrete_types in product(map(eachindex(parameter_types)) do i
                    branches, leaves = Type[parameter_types[i]], DataType[]
                    no_specialize = (nospecialize >> (i - 1)) & 1 == 1

                    while !isempty(branches)
                        branch = pop!(branches)

                        if isconcretetype(branch)
                            push!(leaves, branch)
                            no_specialize && break
                        else append!(branches, leaf_types(branch, target))
                        end
                    end

                    leaves
                end...)
                    precompile_concrete(x, concrete_types; kwargs...)
                end
            end
        elseif all(isconcretetype, parameter_types)
            precompile_concrete(x, (parameter_types...,); kwargs...)
        end

        if method_types in target
            for parameter_type in parameter_types
                check_cache(parameter_type; target, kwargs...)
            end
        end
    end
precompile_method(x, nospecialize, ::UnionAll; _...) = nothing

signature(x, types) =
    signature(x) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'
signature(x::Union{Function, Type}) = repr(x)
signature(@nospecialize ::T) where T = "(::" * repr(T) * ')'

# TODO: `methodswith`
speculate_cached(x::Function; kwargs...) = precompile_methods(x; kwargs...)
speculate_cached(x::Module; target, kwargs...) =
    for name in names(x; all = all_names in target, imported = imported_names in target)
        isdefined(x, name) && check_cache(getfield(x, name); target, kwargs...)
    end
function speculate_cached(x::Union{DataType, UnionAll, Union}; target, kwargs...)
    precompile_methods(x; target, kwargs...)

    for type in leaf_types(x, target)
        check_cache(type; target, kwargs...)
    end
end

union_all_cache!(types, _, x::DataType) =
    append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, target, x::UnionAll) = union_all_cache!(types, target, x.body)
union_all_cache!(types, target, x::Union) = for type in leaf_types(x, target)
    union_all_cache!(types, target, type)
end
