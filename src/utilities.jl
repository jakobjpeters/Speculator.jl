
cache!(f, cache, object_id, x; kwargs...) = if !(object_id in cache)
    push!(cache, object_id)
    f(x; kwargs...)
end

check_cache(x; cache, kwargs...) = cache!((x; kwargs...) -> speculate_cached(x; kwargs...),
    cache, objectid(x), x; cache, kwargs...)

is_not_vararg(::typeof(Vararg)) = false
is_not_vararg(_) = true

leaf_types(x::DataType, target) = abstracts in target && !(Any <: x) ? subtypes(x) : []
leaf_types(x::UnionAll, target) =
    caches in target ? filter(!isnothing, union_all_cache!([], target, x)) : []
leaf_types(x::Union, target) = unions in target ? uniontypes(x) : []

function log(f, background)
    flag = background && isdefined(Base, :active_repl)
    flag && print(stderr, "\33[2K\r\33[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

precompile_methods(x; kwargs...) = for method in methods(x)
    precompile_method(x, method.nospecialize, method.sig; kwargs...)
end

precompile_method(x, nospecialize, sig::DataType; background, count, target, verbosity, kwargs...) =
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if all(is_not_vararg, parameter_types)
            for concrete_types in product(map(eachindex(parameter_types)) do i
                branches, leaves = Type[parameter_types[i]], DataType[]

                if (nospecialize >> (i - 1)) & 1 == 1
                    while !isempty(branches)
                        branch = pop!(branches)

                        if isconcretetype(branch)
                            push!(leaves, branch)
                            break
                        else append!(branches, leaf_types(branch, target))
                        end
                    end
                else
                    while !isempty(branches)
                        branch = pop!(branches)
                        isconcretetype(branch) ? push!(leaves, branch) :
                            append!(branches, leaf_types(branch, target))
                    end
                end

                leaves
            end...)
                if precompile(x, concrete_types)
                    debug in verbosity &&
                        log(() -> (@info "Precompiled `$(signature(x, concrete_types))`"), background)
                    count[] += 1
                elseif warn in verbosity
                    log(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, concrete_types))`"), background)
                end
            end
        end

        if parameters in target
            for parameter_type in parameter_types
                check_cache(parameter_type; background, count, target, verbosity, kwargs...)
            end
        end
    end
precompile_method(x, nospecialize, ::UnionAll; _...) = nothing

signature(f, types) =
    signature(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'
signature(f::Union{Function, Type}) = repr(f)
signature(::T) where T = "(::" * repr(T) * ')'

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
function speculate_cached(x::T; cache, callable_cache, target, kwargs...) where T
    object_id = objectid(T)
    callables in target && cache!((x; kwargs...) -> precompile_methods(x; kwargs...),
        callable_cache, object_id, x; cache, callable_cache, target, kwargs...)
    cache!((x; kwargs...) -> speculate_cached(x; kwargs...),
        cache, object_id, T; cache, callable_cache, target, kwargs...)
end

union_all_cache!(types, _, x::DataType) = append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, target, x::UnionAll) = union_all_cache!(types, target, x.body)
union_all_cache!(types, target, x::Union) = for type in leaf_types(x, target)
    union_all_cache!(types, target, type)
end
