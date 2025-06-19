
using Test: @testset

for name ∈ (:Aqua, :ExplicitImports, :JET, :Speculator)
    @info "Testing $name"
    @testset "$name" include("Test$name.jl")
end
