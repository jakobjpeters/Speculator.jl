
using MethodAnalysis: visit
using Speculator
using Test: @test

const _methods = Method[]
const _read, _write = pipe = Pipe()
cache_methods(x::Method) = (push!(_methods, x); true)
cache_methods((@nospecialize _)) = true
visit(cache_methods)
redirect_stderr(() -> speculate(;
    dry = true, target = all_names | instance_types, verbosity = review), pipe)
close(_write)
const count = length(_methods)
const _count = parse(Int, only(match(r"(\d+)", read(_read, String))))
within_one_percent(x, y) = abs((x / y) - 1) < 0.01
@test within_one_percent(count, _count) && within_one_percent(_count, count)

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
