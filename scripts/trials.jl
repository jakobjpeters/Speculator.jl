
using Base: find_package
using Pkg: PackageSpec, add
using Serialization: deserialize
using Speculator: initialize_parameters, silent

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
const predicate, x, limit = load_data(data_path)

trial(dry) = @elapsed initialize_parameters(x, false, dry, false, limit, "", predicate, silent)

trial(true)
write(time_path, max(0, trial(false) - trial(false)))
