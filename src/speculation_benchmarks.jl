
"""
    SpeculationBenchmark <: Any
    SpeculationBenchmark(predicate = Returns(true), value;
        limit::Integer = $default_limit, trials::Integer = $default_trials
    )

Benchmark the compilation time in the workload generated by
`speculate(predicate,\u00A0value;\u00A0samples,\u00A0limit)`.

This runs a compilation workload for each of the `trials`.
Each trial occurs in a new process so that compiled methods are not cached across trials.
The trials run the workload with `dry\u00A0=\u00A0true` to compile
methods in Speculator.jl, then `dry\u00A0=\u00A0false` to measure
the runtime within Speculator.jl and `precompile`,
and finally `dry = false` to measure the runtime within Speculator.jl.
The result of a trial, an estimate of the runtime of calls to `precompile` in the workload,
is the difference between the second and third runs.

See also [`speculate_repl`](@ref) and [`speculate`](@ref).

!!! tip
    Initializing a temporary project and running precompilation
    workloads may take a substantial amount of time to complete.
    It is recommended to select an appropriate workload using
    `speculate(;\u00A0dry\u00A0=\u00A0true,\u00A0verbosity\u00A0=\u00A0debug\u00A0|\u00A0review)`
    before creating a benchmark.

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

    function SpeculationBenchmark(predicate, x;
        limit = default_limit, trials::Integer = default_trials
    )
        @nospecialize

        _active_project = active_project()
        new_project_directory = mktempdir()
        new_project_path = joinpath(new_project_directory, "Project.toml")
        package_path = dirname(@__DIR__)
        data_path, time_path = tempname(), tempname()
        times = Float64[]

        @info "Instantiating temporary project environment for `SpeculationBenchmark`"
        resolve()
        cp(_active_project, new_project_path)
        cp(
            joinpath(dirname(_active_project), "Manifest.toml"),
            joinpath(new_project_directory, "Manifest.toml")
        )
        activate(new_project_path)
        develop(; path = package_path)
        add(["Pkg", "Serialization"])
        instantiate()
        activate(_active_project)
        serialize(data_path, (predicate, x, limit))

        for i in 1:trials
            @info "Running trial `$i`"
            run(Cmd([
                "julia",
                "--project=$new_project_path",
                "--eval",
                "include($(repr(joinpath(package_path, "scripts", "trials.jl"))))",
                data_path,
                time_path
            ]))
            push!(times, read(time_path, Float64))
        end

        new(times)
    end
    function SpeculationBenchmark(x; parameters...)
        @nospecialize
        SpeculationBenchmark(default_predicate, x; parameters...)
    end
end

eltype(::Type{SpeculationBenchmark}) = Float64

firstindex(sb::SpeculationBenchmark) = firstindex(sb.times)

getindex(sb::SpeculationBenchmark, i::Integer) = getindex(sb.times, i)

iterate(sb::SpeculationBenchmark, i::Integer) = iterate(sb.times, i)
iterate(sb::SpeculationBenchmark) = iterate(sb.times)

lastindex(sb::SpeculationBenchmark) = lastindex(sb.times)

length(sb::SpeculationBenchmark) = length(sb.times)

function show(io::IO, ::MIME"text/plain", sb::SpeculationBenchmark)
    times = sb.times
    samples = length(times)
    i = (samples + 1) ÷ 2
    median = begin
        if isodd(samples) partialsort(times, i)
        else sum(partialsort(times, i:(i + 1))) / 2
        end
    end

    join(io, [
        "Precompilation benchmark with `$samples` samples:",
        "  Mean:      `$(round_time(sum(times) / samples))`",
        "  Median     `$(round_time(median))`",
        "  Minimum:   `$(round_time(minimum(times)))`",
        "  Maximum:   `$(round_time(maximum(times)))`"
    ], '\n')
end
