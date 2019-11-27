

const LIBS = (:libc,)

const VERS_C90 = (:c89, :c90, :gnu89, :gnu90,)
const VERS_C99 = (:c99, :gnu99,)
const VERS_C11 = (:c11, :gnu11,)
const VERS_C18 = (:c17, :c18, :gnu17, :gnu18,)
const VERS = (VERS_C90..., VERS_C99..., VERS_C11..., VERS_C18...)

default_version(jl::Julia, tgt::Target, dist::Distro) = :c99

for LIB in LIBS
	SystemBindings.Library{LIB}(jl::Julia, tgt::Target, dist::Distro) = Library{LIB, default_version(jl, tgt, dist)}(jl, tgt, dist)
	for VER in VERS
		SystemBindings.Library{LIB, VER}(jl::Julia, tgt::Target, dist::Distro) = Library{LIB, VER}()
	end
end


# bindings for generic Linux systems
let
	for LIB in LIBS, VER in VERS
		SystemBindings.Binding(jl::Julia, tgt::Target{A, v, :linux, :gnu}, dist::Distro, lib::Library{LIB, VER}, cust::Customization{:default}) where {A, v} = Binding(jl, tgt, dist, lib, cust, depends, atdevel, context)
	end
	
	depends(b::Binding) = Binding[]
	atdevel(b::Binding) = joinpath(@__DIR__, "atdevel.jl")
	
	function context(b::Binding)
		libsPath = system_libraries(b)
		libs = nothing
		
		hdrsPath = system_headers(b)
		hdrs = [
			"assert.h",
			"ctype.h",
			"errno.h",
			"float.h",
			"limits.h",
			"locale.h",
			"math.h",
			"setjmp.h",
			"signal.h",
			"stdarg.h",
			"stddef.h",
			"stdio.h",
			"stdlib.h",
			"string.h",
			"time.h",
		]
		version(library(b)) in VERS_C90 || append!(hdrs, [
			"complex.h",
			"fenv.h",
			"inttypes.h",
			"iso646.h",
			"stdbool.h",
			"stdint.h",
			"tgmath.h",
			"wchar.h",
			"wctype.h",
		])
		version(library(b)) in VERS_C90 || version(library(b)) in VERS_C99 || append!(hdrs, [
			"stdalign.h",
			"stdatomic.h",
			"stdnoreturn.h",
			"threads.h",
			"uchar.h",
		])
		
		ctx = ConverterContext(libs) do decl
			header = filename(decl)
			name   = spelling(decl)
			
			# decl isa CLFunctionDecl && name in (
			# 	"alloca",
			# 	"atexit",
			# ) && return false
			
			startswith(name, "__") && (decl isa CLFunctionDecl || decl isa CLVarDecl || decl isa CLMacroDefinition) && return false
			
			return true
		end
		parse_headers!(ctx, hdrs, args = ["-std=$(version(library(b)))"], builtin = true)
		return ctx
	end
end
