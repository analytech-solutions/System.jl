module SystemBindings
	import CBindingGen
	
	
	export Julia, Target, Distro, Library, Customization, Binding
	export major, minor, patch, arch, vendor, system, abi, name, version, generate
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
		deps::Vector{Library}
		atdev::String
		conv::CBindingGen.ConverterContext
	end
	Binding(jl::Julia, tgt::Target, dist::Distro, lib::Library, cust::Customization = Customization(jl, tgt, dist, lib)) = error("System binding is not specified, please implement a `SystemBindings.Binding(::Julia{$(repr(major(jl))), $(repr(minor(jl))), $(repr(patch(jl)))}, ::Target{$(repr(arch(tgt))), $(repr(vendor(tgt))), $(repr(system(tgt))), $(repr(abi(tgt)))}, ::Distro{$(repr(name(dist))), $(repr(version(dist)))}, ::Library{$(repr(name(dist))), $(repr(version(dist)))}, ::Customization{$(repr(name(cust)))}) = ...` method")
	Binding(lib::Library) = Binding(Julia(), Target(), Distro(), lib)
	
	julia(b::Binding) = b.jl
	target(b::Binding) = b.tgt
	distro(b::Binding) = b.dist
	library(b::Binding) = b.lib
	custom(b::Binding) = b.cust
	
	Base.dirname(b::Binding) = joinpath(dirname(julia(b)), dirname(target(b)), dirname(distro(b)), dirname(library(b)), dirname(custom(b)))
	
	gendir() = joinpath(Base.DEPOT_PATH[1], "bindings")
	clean() = rm(gendir(), force = true, recursive = true)
	
	function clean(b::Binding; clean_deps::Bool = false)
		if clean_deps
			for dep in b.deps
				clean(Binding(julia(b), target(b), distro(b), dep, Customization(julia(b), target(b), distro(b), dep)), clean_deps = true)
			end
		end
		rm(joinpath(gendir(), dirname(b)), force = true, recursive = true)
	end
	
	function generate(b::Binding)
		for dep in b.deps
			generate(Binding(julia(b), target(b), distro(b), dep, Customization(julia(b), target(b), distro(b), dep)))
		end
		basedir = joinpath(gendir(), dirname(b))
		CBindingGen.generate(b.conv, basedir)
		open(joinpath(basedir, "$(name(library(b))).jl"), "w") do file
			write(file, """
			module $(name(library(b)))
				import CBinding
				
				include(joinpath(Base.DEPOT_PATH[1], "$(relpath(b.atdev, Base.DEPOT_PATH[1]))"))
				include(joinpath(Base.DEPOT_PATH[1], "$(relpath(joinpath(basedir, "atcompile.jl"), Base.DEPOT_PATH[1]))"))
				function __init__()
					include(joinpath(Base.DEPOT_PATH[1], "$(relpath(joinpath(basedir, "atload.jl"), Base.DEPOT_PATH[1]))"))
				end
			end
			""")
		end
	end
	
	
	
	include("targets.jl")
	include("distros.jl")
	include("systems.jl")
	
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
