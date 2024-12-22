
using Base: find_package
using Pkg: PackageSpec, add
using Serialization: deserialize
using Speculator: silent, speculate

load_data(path) =
    try deserialize(path)
    catch e
        if e isa KeyError
            key = e.key
            name = key.name

            redirect_stderr(devnull) do
                # TODO: catch error in `add`
                isnothing(find_package(name)) && add(PackageSpec(name, key.uuid))
                @eval using $(Symbol(name))
            end
            load_data(data_path)
        else rethrow()
        end
    end

const data_path, time_path = ARGS
const predicate, x, maximum_methods = load_data(data_path)

trial(dry) = @elapsed speculate(predicate, x; dry, maximum_methods, verbosity = silent)

trial(true)
write(time_path, trial(false) - trial(false))
