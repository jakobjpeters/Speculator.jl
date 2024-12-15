
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

function ignore!(f, ignore, object_id, x; kwargs...)
    @nospecialize
    if !(object_id in ignore)
        push!(ignore, object_id)
        f(x; kwargs...)
    end
end

function check_ignore!(x::Union{DataType, Function, Module, UnionAll, Union}; ignore_types, kwargs...)
    @nospecialize
    ignore!((x; kwargs...) -> begin
        @nospecialize
        speculate_ignored(x; kwargs...)
    end, ignore_types, objectid(x), x; ignore_types, kwargs...)
end
function check_ignore!(x::T; ignore_callables, ignore_types, target, kwargs...) where T
    @nospecialize
    object_id = objectid(T)
    callable_objects ⊆ target && ignore!((x; kwargs...) -> begin
        @nospecialize
        precompile_methods(x; kwargs...)
    end, ignore_callables, object_id, x; ignore_callables, ignore_types, target, kwargs...)
    ignore!((x; kwargs...) -> begin
        @nospecialize
        speculate_ignored(x; kwargs...)
    end, ignore_types, object_id, T; ignore_callables, ignore_types, target, kwargs...)
end

is_not_vararg(::typeof(Vararg)) = false
is_not_vararg(_) = true

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

function precompile_method(x, nospecialize, sig::DataType;
    max_methods, product_cache, subtype_cache, target, kwargs...)
    @nospecialize
    if !(Tuple <: sig)
        parameter_types = sig.types[(begin + 1):end]

        if abstract_methods ⊆ target
            if all(is_not_vararg, parameter_types)
                product_types = map(eachindex(parameter_types)) do i
                    parameter_type = parameter_types[i]
                    get!(product_cache, objectid(parameter_type)) do
                        branches, leaves = Type[parameter_type], DataType[]
                        no_specialize = (nospecialize >> (i - 1)) & 1 == 1

                        while !isempty(branches)
                            branch = pop!(branches)

                            if isconcretetype(branch) &&
                                !any(type -> type <: branch, [DataType, UnionAll, Union])
                                push!(leaves, branch)
                                no_specialize && break
                            else append!(branches, subtypes!(branch, subtype_cache, target))
                            end
                        end

                        leaves
                    end
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
                check_ignore!(parameter_type;
                    max_methods, product_cache, subtype_cache, target, kwargs...)
            end
        end
    end
end
precompile_method(x, nospecialize, t::UnionAll; _...) = @nospecialize

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

function speculate_ignored(x::Function; kwargs...)
    @nospecialize
    precompile_methods(x; kwargs...)
end
function speculate_ignored(x::Module; target, kwargs...)
    @nospecialize
    for name in names(x; all = all_names ⊆ target, imported = imported_names ⊆ target)
        isdefined(x, name) && check_ignore!(getfield(x, name); target, kwargs...)
    end
end
function speculate_ignored(x::Union{DataType, UnionAll, Union}; subtype_cache, target, kwargs...)
    @nospecialize
    precompile_methods(x; subtype_cache, target, kwargs...)

    for type in subtypes!(x, subtype_cache, target)
        check_ignore!(type; subtype_cache, target, kwargs...)
    end
end

subtypes!(x::DataType, subtype_cache, target) =
    if abstract_subtypes ⊆ target
        _subtypes = get!(() -> subtypes(x), subtype_cache, objectid(x))
        Any <: x ? filter!(subtype -> !(Any <: subtype), _subtypes) : _subtypes
    else []
    end
subtypes!(x::UnionAll, subtype_cache, target) =
    union_all_caches ⊆ target ? union_all_cache!([], subtype_cache, target, x) : []
subtypes!(x::Union, _, target) = union_types ⊆ target ? uniontypes(x) : []

union_all_cache!(types, _, _, x::DataType) =
    append!(types, Iterators.filter(!isnothing, x.name.cache))
union_all_cache!(types, subtype_cache, target, x::UnionAll) =
    union_all_cache!(types, subtype_cache, target, x.body)
function union_all_cache!(types, subtype_cache, target, x::Union)
    for type in subtypes!(x, subtype_cache, target)
        union_all_cache!(types, subtype_cache, target, type)
    end

    types
end
