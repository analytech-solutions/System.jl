module SystemBindings
	import CBindingGen
	
	
	export Target, Distro, Library, Binding
	export arch, vendor, system, abi
	export name, version
	export target, distro, library
	export system_headers, system_libraries
	export @sys
	
	
	# in auto-generated bindings, macros can be used to avoid naming conflicts between Julia and C, so `@SystemBindings().include(...)` will not conflict with `include(...)`
	macro SystemBindings() return @__MODULE__ end
	
	
	# target triple: https://clang.llvm.org/docs/CrossCompilation.html#target-triple
	struct Target{arch, vendor, system, abi}
	end
	function Target()
		(arch, ven, sys, abi) = map(Symbol, split(lowercase(Base.MACHINE), '-'))
		return Target{arch, ven, sys, abi}()
	end
	
	arch(::Target{A, v, s, a}) where {A, v, s, a} = A
	vendor(::Target{A, v, s, a}) where {A, v, s, a} = v
	system(::Target{A, v, s, a}) where {A, v, s, a} = s
	abi(::Target{A, v, s, a}) where {A, v, s, a} = a
	
	Base.dirname(tgt::Target) = "$(arch(tgt))-$(vendor(tgt))-$(system(tgt))-$(abi(tgt))"
	
	
	struct Distro{name, version}
	end
	Distro() = Distro(Target())
	Distro(tgt::Target) = error("Unable to detect distribution, please implement a `SystemBindings.Distro(::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}) = ...` method")
	
	name(::Distro{n, v}) where {n, v} = n
	version(::Distro{n, v}) where {n, v} = v
	
	system_headers() = system_headers(Target(), Distro())
	system_libraries() = system_libraries(Target(), Distro())
	
	Base.dirname(dist::Distro) = "$(name(dist))-$(version(dist))"
	
	
	struct Library{name, version}
	end
	Library(name::Symbol) = Library{name}(Target(), Distro())
	Library(name::Symbol, version::Symbol) = Library{name, version}(Target(), Distro())
	Library{n}(tgt::Target, dist::Distro) where {n} = error("Unsupported library, please implement a `SystemBindings.Library{$(n)}(::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}) = ...` method")
	Library{n, v}(tgt::Target, dist::Distro) where {n, v} = error("Unsupported library or version, please implement a `SystemBindings.Library{$(n), $(v)}(::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}) = ...` method")
	
	name(::Library{n, v}) where {n, v} = n
	version(::Library{n, v}) where {n, v} = v
	
	Base.dirname(lib::Library) = replace("$(name(lib))-$(version(lib))", r"\W" => "_")
	
	
	struct Binding{lib<:Library}
		context::Function
		depends::Vector{Binding}
		atcompile::Union{String, Nothing}
		atload::Union{String, Nothing}
		
		Binding{lib}(context::Function, depends = Binding[], atcompile = nothing, atload = nothing) where {lib<:Library} = new{lib}(context, depends, atcompile, atload)
	end
	Binding(lib::Library) = Binding(Target(), Distro(), lib)
	Binding(tgt::Target, dist::Distro, lib::Library) = error("System binding is not specified, please implement a `SystemBindings.Binding(::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}, ::Library{$(repr(name(dist))), $(repr(version(dist)))}) = ...` method")
	
	library(b::Binding{l}) where {l} = l()
	context(b::Binding) = b.context()
	depends(b::Binding) = b.depends
	atcompile(b::Binding) = b.atcompile
	atload(b::Binding) = b.atload
	
	bindings_dir(b::Binding) = joinpath(bindings_dir(), dirname(Target()), dirname(Distro()), dirname(library(b)))
	bindings_dir() = joinpath(Base.DEPOT_PATH[1], "bindings")
	clean() = rm(bindings_dir(), force = true, recursive = true)
	
	# TODO: this should clean up bindings that depended on it too
	function clean(b::Binding; clean_deps::Bool = false)
		rm(bindings_dir(b), force = true, recursive = true)
		clean_deps && foreach(dep -> clean(dep, clean_deps = true), depends(b))
	end
	
	function generate(b::Binding)
		foreach(generate, depends(b))
		
		CBindingGen.generate(context(b), joinpath(bindings_dir(b), "src"))
		open(joinpath(bindings_dir(b), "src", dirname(library(b))*".jl"), "w") do file
			compile = isnothing(atcompile(b)) ? "" : "@SystemBindings().Base.include(@SystemBindings().@__MODULE__, @SystemBindings().joinpath(@SystemBindings().dirname(@SystemBindings().pathof(@SystemBindings())), $(repr(relpath(atcompile(b), dirname(pathof(SystemBindings)))))))"
			load = isnothing(atload(b)) ? "" : "@SystemBindings().Base.include(@SystemBindings().@__MODULE__, @SystemBindings().joinpath(@SystemBindings().dirname(@SystemBindings().pathof(@SystemBindings())), $(repr(relpath(atload(b), dirname(pathof(SystemBindings)))))))"
			
			write(file, """
			baremodule $(dirname(library(b)))
				const $(name(library(b))) = $(dirname(library(b)))
				
				using CBinding: @CBinding, @ctypedef, @cstruct, @cunion, @carray, @calign, @cenum, @cextern, @cbindings
				using SystemBindings: @SystemBindings, @sys
				
				$(compile)
				@SystemBindings().Base.include(@SystemBindings().@__MODULE__, @SystemBindings().joinpath(@SystemBindings().@__DIR__, "atcompile.jl"))
				function __init__()
					$(load)
					@SystemBindings().Base.include(@SystemBindings().@__MODULE__, @SystemBindings().joinpath(@SystemBindings().@__DIR__, "atload.jl"))
				end
			end
			""")
		end
	end
	
	
	macro sys(exprs...) ; return _sys(__module__, exprs...) ; end
	
	# TODO: provide more _sys functions to handle versions/version ranges/etc as well as customizations
	function _sys(mod::Module, expr::Expr)
		Base.is_expr(expr, :using, 1) || Base.is_expr(expr, :import, 1) || error("Expected to find a `using ...` or `import ...` statement in @sys usage")
		
		name = expr.args[1]
		if Base.is_expr(name, :(:)) && length(name.args) >= 1
			name = name.args[1]
		end
		Base.is_expr(name, :., 1) || error("Expected a library name in @sys using/import statement, but found `$(name)`")
		
		lib = Library(name.args[1])
		pushfirst!(name.args, Symbol(dirname(lib)))
		
		b = Binding(lib)
		isdir(joinpath(bindings_dir(b))) || generate(b)
		
		return expr
	end
	
	
	include("distros.jl")
	include("bindings.jl")
	
	
	function __init__()
		push!(Base.LOAD_PATH, joinpath(bindings_dir(), dirname(Target()), dirname(Distro())))
	end
end
