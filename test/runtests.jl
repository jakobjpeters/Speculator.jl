
using MethodAnalysis: visit
using Speculator
using Test: @test

const _methods = Set{Method}()
const _read, _write = pipe = Pipe()
check_signature(x::DataType) = all(isconcretetype, x.types[(begin + 1):end]) &&
    !any(type -> type <: x, [DataType, UnionAll, Union])
check_signature(_) = false
function cache_methods(x::Method)
    check_signature(x.sig) && x.module != Core && push!(_methods, x)
    true
end
cache_methods((@nospecialize _)) = true
visit(cache_methods)
redirect_stderr(() -> speculate(;
    dry = true, target = all_names | instance_types, verbosity = review), pipe)
close(_write)
@test length(_methods) < parse(Int, only(match(r"(\d+)", read(_read, String))))

module X end
const path = "precompile.jl"
rm(path; force = true)
speculate(X; path, dry = true)
@test !isfile(path)
speculate(X; path)
@test isfile(path)

@test_nowarn speculate()

const path = tempname()
speculate(; path)
@test (include(path); true)
