
using Base: active_project
using Pkg: activate, add, develop, instantiate, resolve

const _active_project = active_project()
const new_project_directory = mktempdir()
const new_project_path = joinpath(new_project_directory, "Project.toml")
const package_path = dirname(@__DIR__)

# resolve()
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
