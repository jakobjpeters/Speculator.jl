
using Base: find_package
using Pkg: PackageSpec, add
using Serialization: deserialize
using Speculator: speculate

load_data(path) =
    try deserialize(path)
    catch e
        if e isa KeyError
            key = e.key
            name = key.name

            redirect_stderr(devnull) do
                isnothing(find_package(name)) && add(PackageSpec(name, key.uuid))
                @eval using $(Symbol(name))
            end
            load_data(data_path)
        else rethrow()
        end
    end

const data_path, time_path = ARGS
const x, ignore, maximum_methods, target = load_data(data_path)

trial(dry) = @elapsed speculate(x;
    dry, ignore, maximum_methods, target, background = false, verbosity = nothing)

trial(true)
write(time_path, trial(false) - trial(false))
