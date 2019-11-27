module SystemBindings
	import CBindingGen
	
	
	export Julia, Target, Distro, Library, Customization, Binding
	export major, minor, patch
	export arch, vendor, system, abi
	export name, version
	export julia, target, distro, library, custom
	export system_headers, system_libraries
	export @sys
	
	
	struct Julia{major, minor, patch}
	end
	function Julia()
		(M, m, p) = (Int(getfield(Base.VERSION, f)) for f in (:major, :minor, :patch))
		return Julia{M, m, p}()
	end
	
	major(::Julia{M, m, p}) where {M, m, p} = M
	minor(::Julia{M, m, p}) where {M, m, p} = m
	patch(::Julia{M, m, p}) where {M, m, p} = p
	
	Base.dirname(jl::Julia) = "$(major(jl)).$(minor(jl)).$(patch(jl))"
	
	
	# target triple: https://clang.llvm.org/docs/CrossCompilation.html#target-triple
	struct Target{arch, vendor, system, abi}
	end
	Target() = Target(Julia())
	Target(jl::Julia) = error("Unable to detect target, please implement a `SystemBindings.Target(::Julia{$(repr(major(jl))), $(repr(minor(jl))), $(repr(patch(jl)))}) = ...` method")
	
	arch(::Target{A, v, s, a}) where {A, v, s, a} = A
	vendor(::Target{A, v, s, a}) where {A, v, s, a} = v
	system(::Target{A, v, s, a}) where {A, v, s, a} = s
	abi(::Target{A, v, s, a}) where {A, v, s, a} = a
	
	Base.dirname(tgt::Target) = "$(arch(tgt))-$(vendor(tgt))-$(system(tgt))-$(abi(tgt))"
	
	
	struct Distro{name, version}
	end
	Distro() = Distro(Julia(), Target())
	Distro(jl::Julia, tgt::Target) = error("Unable to detect distribution, please implement a `SystemBindings.Distro(::Julia{$(repr(major(jl))), $(repr(minor(jl))), $(repr(patch(jl)))}, ::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}) = ...` method")
	
	name(::Distro{n, v}) where {n, v} = n
	version(::Distro{n, v}) where {n, v} = v
	
	Base.dirname(dist::Distro) = "$(name(dist))-$(version(dist))"
	
	
	struct Library{name, version}
	end
	Library(name::Symbol) = Library{name}(Julia(), Target(), Distro())
	Library(name::Symbol, version::Symbol) = Library{name, version}(Julia(), Target(), Distro())
	Library{name}(jl::Julia, tgt::Target, dist::Distro) where {name} = error("Unsupported library or version, please implement a `SystemBindings.Library{$(name)}(::Julia{$(repr(major(jl))), $(repr(minor(jl))), $(repr(patch(jl)))}, ::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}) = ...` method")
	
	name(::Library{n, v}) where {n, v} = n
	version(::Library{n, v}) where {n, v} = v
	
	Base.dirname(lib::Library) = "$(name(lib))-$(version(lib))"
	
	
	struct Customization{name}
		Customization(name::Symbol) = new{name}()
	end
	Customization(jl::Julia, tgt::Target, dist::Distro, lib::Library) = Customization(:default)
	# NOTE: hook in a customization by defining a specialized method to return your customization
	
	name(::Customization{n}) where {n} = n
	
	Base.dirname(cust::Customization) = "$(name(cust))"
	
	
	struct Binding
		jl::Julia
		tgt::Target
		dist::Distro
		lib::Library
		cust::Customization
		
		depends::Function
		atdevel::Function
		context::Function
	end
	Binding(jl::Julia, tgt::Target, dist::Distro, lib::Library, cust::Customization = Customization(jl, tgt, dist, lib)) = error("System binding is not specified, please implement a `SystemBindings.Binding(::Julia{$(repr(major(jl))), $(repr(minor(jl))), $(repr(patch(jl)))}, ::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}, ::Library{$(repr(name(dist))), $(repr(version(dist)))}, ::Customization{$(repr(name(cust)))}) = ...` method")
	Binding(lib::Library) = Binding(Julia(), Target(), Distro(), lib)
	
	julia(b::Binding) = b.jl
	target(b::Binding) = b.tgt
	distro(b::Binding) = b.dist
	library(b::Binding) = b.lib
	custom(b::Binding) = b.cust
	depends(b::Binding) = b.depends(b)
	atdevel(b::Binding) = b.atdevel(b)
	context(b::Binding) = b.context(b)
	
	Base.dirname(b::Binding) = joinpath(dirname(julia(b)), dirname(target(b)), dirname(distro(b)), dirname(library(b)), dirname(custom(b)))
	
	system_headers(b::Binding) = system_headers(target(b), distro(b))
	system_libraries(b::Binding) = system_libraries(target(b), distro(b))
	
	generated_file(b::Binding) = joinpath(bindings_dir(b), "$(name(library(b))).jl")
	bindings_dir(b::Binding) = joinpath(bindings_dir(), dirname(b))
	bindings_dir() = joinpath(Base.DEPOT_PATH[1], "bindings")
	clean() = rm(bindings_dir(), force = true, recursive = true)
	
	# TODO: this should clean up bindings that depended on it too
	function clean(b::Binding; clean_deps::Bool = false)
		rm(bindings_dir(b), force = true, recursive = true)
		clean_deps && foreach(dep -> clean(dep, clean_deps = true), depends(b))
	end
	
	function generate(b::Binding)
		foreach(generate, depends(b))
		atdev = relpath(atdevel(b), bindings_dir(b))
		CBindingGen.generate(context(b), bindings_dir(b))
		open(generated_file(b), "w") do file
			write(file, """
			baremodule $(name(library(b)))
				import CBinding
				import CBinding.Base
				
				if CBinding.Base.isfile(CBinding.Base.joinpath(CBinding.Base.@__DIR__, $(repr(atdev))))
					CBinding.Base.include(CBinding.Base.@__MODULE__, CBinding.Base.joinpath(CBinding.Base.@__DIR__, $(repr(atdev))))
				end
				CBinding.Base.include(CBinding.Base.@__MODULE__, CBinding.Base.joinpath(CBinding.Base.@__DIR__, "atcompile.jl"))
				function __init__()
					CBinding.Base.include(CBinding.Base.@__MODULE__, CBinding.Base.joinpath(CBinding.Base.@__DIR__, "atload.jl"))
				end
			end
			""")
		end
	end
	
	function load(b::Binding; mod::Module = (@__MODULE__).Libraries)
		@eval(Main, $(QuoteNode(name(library(b)))) in names($(mod), all=true)) || ((@info "loading") ; @eval(Main, Base.include($(mod), $(generated_file(b)))))
		return @eval(Main, getproperty($(mod), $(QuoteNode(name(library(b))))))
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
		pushfirst!(name.args, :SystemBindings, :Libraries)
		
		b = Binding(Library(last(name.args)))
		isfile(generated_file(b)) || generate(b)
		
		return quote
			SystemBindings.load($(b))
			$(expr)
		end
	end
	
	
	include("targets.jl")
	include("distros.jl")
	include("systems.jl")
	
	baremodule Libraries
	end
	
	module Bindings
		for entry in readdir(@__DIR__)
			lib = joinpath(@__DIR__, entry, "bindings.jl")
			isfile(lib) && @eval module $(Symbol(entry))
				using ...SystemBindings
				using ...SystemBindings.CBindingGen
				using ...SystemBindings.CBindingGen.Clang
				
				include($(lib))
			end
		end
	end
end
