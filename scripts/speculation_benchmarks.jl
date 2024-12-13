using Serialization: deserialize
using Speculator: speculate

const data_path, time_path = ARGS
const x, ignore, max_methods, target = deserialize(data_path)

trial(dry) = @elapsed speculate(x;
    dry, ignore, max_methods, target, background = false, verbosity = nothing)

trial(true)
write(time_path, trial(false) - trial(false))
