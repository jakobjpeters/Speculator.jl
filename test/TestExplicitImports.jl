
module TestExplicitImports

import Speculator
using ExplicitImports:
    check_all_explicit_imports_are_public, check_all_explicit_imports_via_owners,
    check_all_qualified_accesses_are_public, check_all_qualified_accesses_via_owners,
    check_no_implicit_imports, check_no_self_qualified_accesses, check_no_stale_explicit_imports
using Test: @test

for (check, ignore) in [
    check_all_qualified_accesses_are_public => (:active_repl_backend, :active_repl, :map),
    check_all_explicit_imports_are_public => (
        :Builtin, :IdSet, :Stateful, :TypeofBottom, :Typeof,
        :checked_mul, :isdeprecated, :issingletontype, :isvarargtype,
        :loaded_modules_array, :mul_with_overflow, :specializations,
        :tail, :typename, :uniontypes, :unsorted_names, :unwrap_unionall
    ),
    check_all_explicit_imports_via_owners => (),
    check_all_qualified_accesses_via_owners => (),
    check_no_implicit_imports => (),
    check_no_self_qualified_accesses => (:compile,),
    check_no_stale_explicit_imports => (:checked_mul,),
]
    @test isnothing(check(Speculator; ignore))
end

end # module
