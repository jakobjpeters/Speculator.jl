
struct CartesianProduct{T}
    input::Vector{Vector{T}}
    output::Vector{T}

    CartesianProduct(input::Vector{Vector{T}}) where T = new{T}(
        input, Vector{T}(undef, length(input))
    )
end

eltype(::Type{CartesianProduct{T}}) where T = Vector{T}

function iterate(cp::CartesianProduct, indices::Vector{Int})
    count, index, input = length(indices), 1, cp.input

    while index ≤ count
        if indices[index] == length(input[index])
            indices[index] = 1
            index += 1
        else
            indices[index] += 1
            break
        end
    end

    count < index ? nothing : (map!(getindex, cp.output, input, indices), indices)
end
function iterate(cp::CartesianProduct{T}) where T
    input = cp.input

    if isempty(input) T[], Int[]
    elseif any(isempty, input) nothing
    else iterate(cp, map(Int ∘ >(1), eachindex(input)))
    end
end

length(cp::CartesianProduct) = mapreduce(length, checked_mul, cp.input; init = 1)
