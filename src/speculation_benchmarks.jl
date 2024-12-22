
"""
    SpeculationBenchmark
    SpeculationBenchmark(
        predicate = $default_predicate,
        ::Any,
        samples::Integer = 8;
        maximum_methods::Integer = $default_maximum_methods
    )

Benchmark the compilation time saved by the precompilation workload ran by [`speculate`](@ref).

For each of the `samples`, this runs a trial precompilation workload.
Each trial occurs in a new process so that precompilation is not cached across trials.
Each trial runs
`speculate(::Any;\u00A0background\u00A0=\u00A0false,\u00A0verbosity\u00A0=\u00A0nothing)`
sequentially with `dry = true` to compile methods in Speculator.jl, `dry = false`
to measure the runtime of methods in Speculator.jl and calls to `precompile`,
and `dry = false` to measure the runtime of methods in
Speculator.jl and the overhead for repeated calls to `precompile`.
The result of a trial, an estimate of the runtime of calls to `precompile` in the workload,
is the difference between the second and third runs.

!!! tip
    Some precompilation workloads take a substantial amount of time to complete.
    It is recommended to select an appropriate workload
    with `speculate` before running a benchmark.

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

    function SpeculationBenchmark(predicate, x, samples::Integer = default_samples;
        maximum_methods = default_maximum_methods)
        @nospecialize
        @show samples

        data_path, time_path = tempname(), tempname()
        times = Float64[]

        serialize(data_path, (predicate, x, maximum_methods))

        for _ in 1:samples
            run(Cmd(["julia", "--project=$(active_project())", "--eval",
                "include(\"$(dirname(dirname((@__FILE__))))/scripts/trials.jl\")",
            data_path, time_path]))
            push!(times, read(time_path, Float64))
        end

        new(times)
    end
    function SpeculationBenchmark(x, samples::Integer)
        @nospecialize
        SpeculationBenchmark(default_predicate, x, samples)
    end
    SpeculationBenchmark(@nospecialize x) = SpeculationBenchmark(x, default_samples)
end

eltype(::Type{SpeculationBenchmark}) = Float64

firstindex(pb::SpeculationBenchmark) = firstindex(pb.times)

getindex(pb::SpeculationBenchmark, i::Integer) = getindex(pb.times, i)

iterate(pb::SpeculationBenchmark, i::Integer) = iterate(pb.times, i)
iterate(pb::SpeculationBenchmark) = iterate(pb.times)

lastindex(pb::SpeculationBenchmark) = lastindex(pb.times)

length(pb::SpeculationBenchmark) = length(pb.times)

function show(io::IO, ::MIME"text/plain", pb::SpeculationBenchmark)
    println(io, "Precompilation benchmark with `$(length(pb))` samples:")
    println(io, "  Mean:    `$(round_time(mean(pb)))`")
    println(io, "  Median:  `$(round_time(median(pb)))`")
    println(io, "  Minimum: `$(round_time(minimum(pb)))`")
    print(io, "  Maximum: `$(round_time(maximum(pb)))`")
end
