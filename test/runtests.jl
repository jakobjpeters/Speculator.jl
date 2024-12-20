
using Base: loaded_modules_array
using MethodAnalysis: visit
using PrecompileSignatures: precompilable
using Speculator
using Test: @test

function count_methods(; parameters...)
    _read, _write = pipe = Pipe()
    redirect_stderr(() -> speculate(; dry = true, verbosity = review, parameters...), pipe)
    close(_write)
    parse(Int, only(match(r"(\d+)", read(_read, String))))
end

const _methods = Set{Method}()
check_signature(x::DataType) = all(isconcretetype, x.types[(begin + 1):end])
check_signature(_) = false
function cache_methods(x::Method)
    check_signature(x.sig) && x.module != Core && push!(_methods, x)
    true
end
cache_methods((@nospecialize _)) = true
visit(cache_methods)
close(_write)
count = count_methods()
@test length(_methods) < count
@test length(precompilables(loaded_modules_array())) < count

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

@test issorted(map(maximum_methods -> count_methods(; maximum_methods), 1:10))
