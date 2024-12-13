
using Serialization: deserialize
using Speculator: speculate

load_data(path) =
    try deserialize(path)
    catch e
        if e isa KeyError
            @eval using $(Symbol(e.key.name))
            load_data(data_path)
        else rethrow()
        end
    end

const data_path, time_path = ARGS
const x, ignore, max_methods, target = load_data(data_path)

trial(dry) = @elapsed speculate(x;
    dry, ignore, max_methods, target, background = false, verbosity = nothing)

trial(true)
write(time_path, trial(false) - trial(false))
