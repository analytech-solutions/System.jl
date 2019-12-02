
module Bindings
	for entry in readdir(@__DIR__)
		lib = joinpath(@__DIR__, entry, "bindings.jl")
		isfile(lib) && @eval module $(Symbol("lib$(entry)"))
			using ...SystemBindings
			using ...SystemBindings.CBindingGen
			using ...SystemBindings.CBindingGen.Clang
			
			include($(lib))
		end
	end
end
