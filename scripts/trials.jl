
using Base: PkgId
using Serialization: deserialize
using Speculator: initialize_parameters, silent

function load_data(path)
    try deserialize(path)
    catch e
        if e isa KeyError
            key = e.key

            if key isa PkgId
                @eval import $(Symbol(key.name))
                load_data(data_path)
            else rethrow()
            end
        else rethrow()
        end
    end
end

const data_path, time_path = ARGS
const predicate, x, limit = load_data(data_path)

trial(dry) = @elapsed initialize_parameters(x, "", false;
    dry, limit, predicate, background_repl = false, verbosity = silent
)

trial(true)
write(time_path, max(0.0001, trial(false) - trial(false)))
