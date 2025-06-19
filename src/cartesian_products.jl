
struct CartesianProduct{T <: Vector}
    input::Vector{T}
    output::T

    CartesianProduct(input::Vector{T}) where T = new{T}(input, T(undef, length(input)))
end

eltype(::Type{CartesianProduct{T}}) where T = T

function iterate(cartesian_product::CartesianProduct, indices::Vector{Int})
    count, index, input = length(indices), firstindex(indices), cartesian_product.input

    while index ≤ count
        if indices[index] == length(input[index])
            indices[index] = 1
            index = nextind(indices, index)
        else
            indices[index] += 1
            break
        end
    end

    count < index ? nothing : (map!(getindex, cartesian_product.output, input, indices), indices)
end
function iterate(cartesian_product::CartesianProduct{T}) where T
    input = cartesian_product.input

    if isempty(input) T(), Int[]
    elseif any(isempty, input) nothing
    else iterate(cartesian_product, map(Int ∘ >(1), eachindex(input)))
    end
end

length(cartesian_product::CartesianProduct) = mapreduce(
    length, checked_mul, cartesian_product.input; init = 1
)
