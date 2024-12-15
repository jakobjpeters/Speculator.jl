
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

include("targets.jl")
include("verbosities.jl")
