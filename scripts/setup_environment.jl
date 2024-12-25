
using Pkg: activate, add, develop, instantiate, resolve

const active_project, new_directory = ARGS
const new_project = joinpath(new_directory, "Project.toml")
const package_path = dirname(@__DIR__)

activate(active_project)
resolve()
cp(active_project, new_project)
cp(
    joinpath(dirname(active_project), "Manifest.toml"),
    joinpath(new_directory, "Manifest.toml")
)
activate(new_project)
develop(; path = dirname(@__DIR__))
add(["Pkg", "Serialization"])
instantiate()
activate(active_project)
