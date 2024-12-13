
"""
    SpeculationBenchmark
    SpeculationBenchmark(::Any, samples::Integer = 2;
        ignore = $default_ignore,
        max_methods::Integer = $default_max_methods,
        target::Union{Target, Nothing} = $default_target
    )

Benchmark the compilation time saved by the precompilation workload
ran by [`speculate`](@ref) with the given keyword parameters.

For each of the `samples`, this runs a trial precompilation workload.
Each trial occurs in a new process, so that precompilation is not cached across trials.
Each trial runs
`speculate(::Any;\u00A0ignore,\u00A0target,\u00A0background\u00A0=\u00A0false,\u00A0verbosity\u00A0=\u00A0nothing)`
sequentially with `dry = true` to compile methods in Speculator.jl, `dry = false`
to measure the runtime of methods in Speculator.jl and calls to `precompile`,
and `dry = false` to measure the runtime of methods in
Speculator.jl and the overhead for repeated calls to `precompile`.
The result of a trial, an estimate of the runtime of calls to `precompile` in the workload,
is the difference between the second and third runs.

The default number of `samples` is small because some precompilation
workloads can take a substantial amount of time to complete.
Increase this parameter for more accurate benchmarks.

See also [`Target`](@ref).

# Interface

This type implements the iteration interface and part of the indexing interface.

- `eltype(::Type{<:SpeculationBenchmark})`
- `firstindex(::SpeculationBenchmark)`
- `getindex(::SpeculationBenchmark, ::Integer)`
- `iterate(::SpeculationBenchmark, ::Integer)`
- `iterate(::SpeculationBenchmark)`
- `lastindex(::SpeculationBenchmark)`
- `length(::SpeculationBenchmark)`
- `show(::IO, ::MIME"text/plain", ::SpeculationBenchmark)`
"""
struct SpeculationBenchmark
    times::Vector{Float64}

    function SpeculationBenchmark(x, samples::Integer = 2;
        ignore = default_ignore, max_methods = default_max_methods, target = default_target)
        @nospecialize

        data_path, time_path = tempname(), tempname()
        times = Float64[]

        serialize(data_path, (x, ignore, max_methods, target))

        for _ in 1:samples
            run(`julia --project=$(active_project()) --eval 'include("scripts/speculation_benchmarks.jl")' $data_path $time_path`)
            push!(times, read(time_path, Float64))
        end

        new(times)
    end
end

eltype(::Type{<:SpeculationBenchmark}) = Float64

firstindex(pb::SpeculationBenchmark) = firstindex(pb.times)

getindex(pb::SpeculationBenchmark, i::Integer) = getindex(pb.times, i)

iterate(pb::SpeculationBenchmark, i::Integer) = iterate(pb.times, i)
iterate(pb::SpeculationBenchmark) = iterate(pb.times)

lastindex(pb::SpeculationBenchmark) = lastindex(pb.times)

length(pb::SpeculationBenchmark) = length(pb.times)

function show(io::IO, ::MIME"text/plain", pb::SpeculationBenchmark)
    println(io, "Precompilation benchmark with `$(length(pb))` samples:")
    println(io, "  Mean:    `$(round(mean(pb); digits = 2))`")
    println(io, "  Median:  `$(round(median(pb); digits = 2))`")
    println(io, "  Minimum: `$(round(minimum(pb); digits = 2))`")
    print(io, "  Maximum: `$(round(maximum(pb); digits = 2))`")
end
