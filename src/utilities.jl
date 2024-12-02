
function cache(f, x; cache, kwargs...)
    object_id = objectid(x)

    if !(object_id in cache)
        push!(cache, object_id)
        f(x; cache, kwargs...)
    end
end

check_cache(x; kwargs...) = cache((x; kwargs...) -> speculate_cached(x; kwargs...), x; kwargs...)

leaf_types(x::DataType) = subtypes(x)
leaf_types(x::Union) = uniontypes(x)

function log(f, background)
    flag = background && isdefined(Base, :active_repl)
    flag && print(stderr, "\33[2K\r\33[A")
    f()
    if flag
        println(stderr)
        refresh_line(active_repl.mistate)
    end
end

maybe_check_cache(::Nothing; _...) = nothing
maybe_check_cache(x; kwargs...) = check_cache(x; kwargs...)

precompile_methods(x; kwargs...) =
    for method in methods(x)
        precompile_method(x, method.sig; kwargs...)
    end

precompile_method(x, sig::DataType; background, verbosity, kwargs...) =
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if all(isconcretetype, parameter_types)
            concrete_types = (parameter_types...,)

            if precompile(x, concrete_types)
                debug in verbosity &&
                    log(() -> (@info "Precompiled `$(signature(x, concrete_types))`"), background)
            elseif warn in verbosity
                log(() -> (@warn "Precompilation failed, please file a bug report in Speculator.jl for:\n`$(signature(x, concrete_types))`"), background)
            end
        end

        for parameter_type in parameter_types
            check_cache(parameter_type; background, verbosity, kwargs...)
        end
    end
precompile_method(x, ::UnionAll; _...) = nothing

signature(f, types) =
    repr(f) * '(' * join(map(type -> "::" * string(type), types), ", ") * ')'

speculate_cached(x::Function; kwargs...) = precompile_methods(x; kwargs...)
speculate_cached(x::Module; kwargs...) = for name in names(x; all = true)
    isdefined(x, name) && check_cache(getfield(x, name); kwargs...)
end
function speculate_cached(x::Union{DataType, Union}; kwargs...)
    precompile_methods(x; kwargs...)

    for type in leaf_types(x)
        check_cache(type; kwargs...)
    end
end
speculate_cached(x::UnionAll; kwargs...) = speculate_union_all(x; kwargs...)
function speculate_cached(x::T; kwargs...) where T
    check_cache(T; kwargs...)
    precompile_methods(x)
end

speculate_union_all(x::DataType; kwargs...) = cache((x; kwargs...) -> foreach(
    maybe_type -> maybe_check_cache(maybe_type; kwargs...), x.name.cache), x; kwargs...)
speculate_union_all(x::UnionAll; kwargs...) =
    cache((x; kwargs...) -> speculate_union_all(x.body; kwargs...), x; kwargs...)
speculate_union_all(x::Union; kwargs...) = cache((x; kwargs...) -> foreach(
    type -> speculate_union_all(type; kwargs...), uniontypes(x)), x; kwargs...)
