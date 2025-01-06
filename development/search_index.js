var documenterSearchIndex = {"docs":
[{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"speculate","category":"page"},{"location":"references/#Speculator.speculate","page":"References","title":"Speculator.speculate","text":"speculate(predicate, value; parameters...)\nspeculate(value; parameters...)\n\nSearch for compilable methods.\n\nSee also install_speculator.\n\ntip: Tip\nUse this in a package to reduce latency.\n\nnote: Note\nThis only runs when called during precompilation or an interactive session, or when writing precompilation directives to a file.\n\nParameters\n\npredicate = Returns(true):   This must accept the signature predicate(::Module, ::Symbol)::Bool.   Returning true specifies to search getproperty(::Module, ::Symbol),   whereas returning false specifies to skip the value.   This is called when searching the names of a Module if the   given module and name satisfy isdefined and !isdeprecated,   and is called when searching for types from method parameters.   The default predicate Returns(true) will search every value,   whereas the predicate Returns(false) will not search any value.   Some useful predicates include Base.isexported,   Base.ispublic, and checking properties of the value itself.\nvalue:   When given a Module, speculate will recursively search its contents   using names(::Module; all = true), for each defined value that   is not deprecated, is not an external module, and satisifes the predicate.   For other values, each of their generic methods   are searched for corresponding compilable methods.\n\nKeyword parameters\n\nbackground::Bool = false:   Specifies whether to run on a thread in the :default pool.   The number of available threads can be determined using Threads.nthreads(:default).\ndry::Bool = false:   Specifies whether to run precompile on generated method signatures.   This is useful for testing with verbosity = debug ∪ review.   Method signatures that are known to be specialized are skipped.   Note that dry must be false to save the directives to a file with the path parameter.\nlimit::Int = 1:   Specifies the maximum number of compilable methods that are generated from a generic method.   Values less than 1 will throw an error.   Otherwise, method signatures will be generated from the Cartesian product each parameter type.   Concrete types and those marked with @nospecialize are used directly.   Otherwise, concrete types are obtained from the subtypes of DataType and Union.   Setting an appropriate value prevents spending too   much time precompiling a single generic method.\npath::String = \"\":   Saves successful precompilation directives to a file   if the path is not empty and it is not a dry run.   Generated methods that are known to have been compiled are skipped.   The resulting directives may require loading additional modules to run.\nverbosity::Verbosity = warn:   Specifies what logging statements to show.   If this function is used to precompile a package,   this should be set to silent or warn.   See also Verbosity.\n\nExamples\n\njulia> module Showcase\n           export g, h\n\n           f() = nothing\n           g(::Int) = nothing\n           h(::Union{String, Symbol}) = nothing\n       end;\n\njulia> speculate(Showcase; verbosity = debug)\n[ Info: Compiled `Main.Showcase.g(::Int)`\n[ Info: Compiled `Main.Showcase.f()`\n\njulia> speculate(Base.isexported, Showcase; verbosity = debug)\n[ Info: Skipped `Main.Showcase.g(::Int)`\n\njulia> speculate(Showcase.h; limit = 2, verbosity = debug)\n[ Info: Compiled `Main.Showcase.h(::String)`\n[ Info: Compiled `Main.Showcase.h(::Symbol)`\n\n\n\n\n\n","category":"function"},{"location":"references/#Input-Speculator","page":"References","title":"Input Speculator","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"install_speculator\nuninstall_speculator","category":"page"},{"location":"references/#Speculator.install_speculator","page":"References","title":"Speculator.install_speculator","text":"install_speculator(\n    predicate = (m, _) -> m ∉ [Base, Core]; background::Bool = true,\nparameters...)\n\nInstall a hook that calls speculate(predicate, value; background, parameters...) on each input value in the REPL.\n\nSubsequent calls to this function may be used to replace the hook. The hook may be removed using uninstall_speculator. This function has no effect in non-interactive sessions.\n\nSee also speculate.\n\ntip: Tip\nUse this in a startup.jl file to reduce latency in the REPL. Since it relies on the REPL being initialized, it should be placed at the end of the file.\n\njulia> install_speculator(; limit = 2, verbosity = debug)\n\njulia> f() = nothing;\n\n[ Info: Compiled `Main.f()`\njulia> g(::Union{String, Symbol}) = nothing;\n\n[ Info: Compiled `Main.g(::Symbol)`\n[ Info: Compiled `Main.g(::String)`\n\n\n\n\n\n","category":"function"},{"location":"references/#Speculator.uninstall_speculator","page":"References","title":"Speculator.uninstall_speculator","text":"uninstall_speculator()\n\nUninstall the hook that may have previously been installed by install_speculator.\n\njulia> uninstall_speculator()\n\n\n\n\n\n","category":"function"},{"location":"references/#All-Modules","page":"References","title":"All Modules","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"AllModules\nall_modules","category":"page"},{"location":"references/#Speculator.AllModules","page":"References","title":"Speculator.AllModules","text":"AllModules\n\nA singleton type whose only value is all_modules.\n\nInterface\n\nshow(::IO, ::AllModules)\n\nExamples\n\njulia> AllModules\nAllModules\n\n\n\n\n\n","category":"type"},{"location":"references/#Speculator.all_modules","page":"References","title":"Speculator.all_modules","text":"all_modules::AllModules\n\nThe singleton constant of AllModules used with speculate to generate a compilation workload using all loaded modules.\n\nExamples\n\njulia> all_modules\nall_modules::AllModules\n\n\n\n\n\n","category":"constant"},{"location":"references/#Verbosities","page":"References","title":"Verbosities","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Verbosity\ndebug\nreview\nsilent\nwarn","category":"page"},{"location":"references/#Speculator.Verbosity","page":"References","title":"Speculator.Verbosity","text":"Verbosity\n\nA flag that determine what logging statements are shown during speculate.\n\nThis is modelled as a set, where silent is the empty set. The non-empty component flags are debug, review, and warn.\n\nInterface\n\nThis type implements part of the AbstractSet interface.\n\nintersect(::Verbosity, ::Verbosity...)\nisdisjoint(::Verbosity, ::Verbosity)\nisempty(::Verbosity)\nissetequal(::Verbosity, ::Verbosity)\nissubset(::Verbosity, ::Verbosity)\nsetdiff(::Verbosity, ::Verboosity...)\nshow(::IO, ::Verbosity)\nsymdiff(::Verbosity, ::Verbosity...)\nunion(::Verbosity, ::Verbosity...)\n\nExamples\n\njulia> silent\nsilent::Verbosity\n\njulia> debug ∪ review\n(debug ∪ review)::Verbosity\n\njulia> debug ⊆ debug ∪ review\ntrue\n\njulia> debug ⊆ warn\nfalse\n\n\n\n\n\n","category":"type"},{"location":"references/#Speculator.debug","page":"References","title":"Speculator.debug","text":"debug::Verbosity\n\nA flag of Verbosity which specifies that speculate will show each successful call to precompile.\n\nExamples\n\njulia> debug\ndebug::Verbosity\n\n\n\n\n\n","category":"constant"},{"location":"references/#Speculator.review","page":"References","title":"Speculator.review","text":"review::Verbosity\n\nA flag of Verbosity which specifies that speculate will show a summary of the number of methods generated, the number of generic methods found, and the duration. If dry = false, this also shows the number of generated methods that were compiled, skipped, and warned.\n\nExamples\n\njulia> debug\ndebug::Verbosity\n\n\n\n\n\n","category":"constant"},{"location":"references/#Speculator.silent","page":"References","title":"Speculator.silent","text":"silent::Verbosity\n\nA flag of Verbosity which specifies that speculate will not show any logging statements.\n\nExamples\n\njulia> silent\nsilent::Verbosity\n\n\n\n\n\n","category":"constant"},{"location":"references/#Speculator.warn","page":"References","title":"Speculator.warn","text":"warn::Verbosity\n\nA flag of Verbosity which specifies that speculate will show warnings for failed calls to precompile. All warnings are considered a bug, and should be filed as an issue in Speculator.jl\n\nExamples\n\njulia> warn\nwarn::Verbosity\n\n\n\n\n\n","category":"constant"},{"location":"#Speculator.jl","page":"Speculator.jl","title":"Speculator.jl","text":"","category":"section"},{"location":"#Introduction","page":"Speculator.jl","title":"Introduction","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"Speculator.jl reduces latency by automatically searching for compilable methods.","category":"page"},{"location":"#Usage","page":"Speculator.jl","title":"Usage","text":"","category":"section"},{"location":"#Installation","page":"Speculator.jl","title":"Installation","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"julia> using Pkg: add\n\njulia> add(\"Speculator\")\n\njulia> using Speculator","category":"page"},{"location":"#Showcase","page":"Speculator.jl","title":"Showcase","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"julia> module Showcase\n           export g, h\n\n           f() = nothing\n           g(::Int) = nothing\n           h(::Union{String, Symbol}) = nothing\n       end;\n\njulia> speculate(Showcase; verbosity = debug)\n[ Info: Compiled `Main.Showcase.g(::Int)`\n[ Info: Compiled `Main.Showcase.f()`\n\njulia> speculate(Base.isexported, Showcase; verbosity = debug)\n[ Info: Skipped `Main.Showcase.g(::Int)`\n\njulia> speculate(Showcase.h; limit = 2, verbosity = debug)\n[ Info: Compiled `Main.Showcase.h(::String)`\n[ Info: Compiled `Main.Showcase.h(::Symbol)`\n\njulia> install_speculator(; limit = 4, verbosity = debug)\n\njulia> i(::Union{String, Symbol}, ::AbstractChar) = nothing;\n\n[ Info: Compiled `Main.i(::Symbol, ::LinearAlgebra.WrapperChar)`\n[ Info: Compiled `Main.i(::String, ::LinearAlgebra.WrapperChar)`\n[ Info: Compiled `Main.i(::Symbol, ::Char)`\n[ Info: Compiled `Main.i(::String, ::Char)`","category":"page"},{"location":"#Features","page":"Speculator.jl","title":"Features","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"Precompile packages\nCompile interactively\nFilter values\nRun in the background\nHandle abstractly typed methods\nSave compilation directives to a file\nShow logging statements","category":"page"},{"location":"#Planned","page":"Speculator.jl","title":"Planned","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"Disable during development using Preferences.jl?\nSupport for UnionAll types?","category":"page"},{"location":"#Similar-Packages","page":"Speculator.jl","title":"Similar Packages","text":"","category":"section"},{"location":"#Precompilation","page":"Speculator.jl","title":"Precompilation","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"CompileTraces.jl\nJuliaScript.jl\nPackageCompiler.jl\nPrecompileSignatures.jl\nPrecompileTools.jl","category":"page"},{"location":"#Reflection","page":"Speculator.jl","title":"Reflection","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"Cthulhu.jl\nJET.jl\nLookingGlass.jl\nMethodAnalysis.jl\nMethodInspector.jl\nPkgCacheInspector.jl\nSnoopCompile.jl\nSnoopCompileCore.jl","category":"page"},{"location":"#Acknowledgements","page":"Speculator.jl","title":"Acknowledgements","text":"","category":"section"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"Credit to Cameron Pfiffer for the initial idea.","category":"page"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"The preexisting package PrecompileSignatures.jl implements similar functionality, notably that PrecompileSignatures.@precompile_signatures ::Module is roughly equivalent to Speculator.speculate(::Module).","category":"page"},{"location":"","page":"Speculator.jl","title":"Speculator.jl","text":"The idea to compile concrete method signatures has also been brought up in PrecompileTools.jl #28.","category":"page"}]
}
