
using Pkg: activate, add, develop, instantiate, resolve

const active_project, new_directory = ARGS
const active_manifest = joinpath(dirname(active_project), "Manifest.toml")
const new_project = joinpath(new_directory, "Project.toml")
const package_path = dirname(@__DIR__)

activate(active_project)
resolve()
ispath(active_project) && cp(active_project, new_project)
ispath(active_manifest) && cp(active_manifest, joinpath(new_directory, "Manifest.toml"))
activate(new_project)
develop(; path = dirname(@__DIR__))
add(["Pkg", "Serialization"])
instantiate()
activate(active_project)
