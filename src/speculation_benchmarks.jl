
"""
    SpeculationBenchmark
    SpeculationBenchmark(predicate = $default_predicate, values;
        samples::Integer = $default_samples, limit::Integer = $default_limit
    )

Benchmark the compilation time in the corresponding
compilation workload generated by [`speculate`](@ref).

For each of the `samples`, this runs a trial precompilation workload.
Each trial occurs in a new process so that compiled methods are not cached across trials.
Each trial runs
`speculate(::Any;\u00A0background\u00A0=\u00A0false,\u00A0verbosity\u00A0=\u00A0nothing)`
sequentially with `dry = true` to compile methods in Speculator.jl, `dry = false`
to measure the runtime of methods in Speculator.jl and calls to `precompile`,
and `dry = false` to measure the runtime of methods in Speculator.jl.
The result of a trial, an estimate of the runtime of calls to `precompile` in the workload,
is the difference between the second and third runs.

To automatically `speculate` values input into the REPL, see also [`speculate_repl`](@ref).

!!! tip
    Initializing a temporary project and running some precompilation
    workloads take a substantial amount of time to complete.
    It is recommended to select an appropriate workload using
    `speculate(; dry = true, verbosity = debug | review)` before running a benchmark.

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
        samples::Integer = default_samples, limit = default_limit
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

        for i in 1:samples
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
