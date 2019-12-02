

const LIBS = (:libc,)

const VERS_C90 = (:c89, :c90, :gnu89, :gnu90,)
const VERS_C99 = (:c99, :gnu99,)
const VERS_C11 = (:c11, :gnu11,)
const VERS_C18 = (:c17, :c18, :gnu17, :gnu18,)
const VERS = (VERS_C90..., VERS_C99..., VERS_C11..., VERS_C18...)

# bindings for generic Linux systems
for LIB in LIBS
	SystemBindings.Library{LIB}(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = Library{LIB, :gnu99}(tgt, dist)
	
	for VER in VERS
		SystemBindings.Library{LIB, VER}(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = Library{LIB, VER}()
		
		SystemBindings.Binding(tgt::Target{A, v, :linux, :gnu}, dist::Distro, lib::Library{LIB, VER}) where {A, v} = Binding{typeof(lib)}(Binding[], joinpath(@__DIR__, "atcompile.jl"), nothing) do
			libs = nothing
			
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
			VER in VERS_C90 || append!(hdrs, [
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
			VER in VERS_C90 || VER in VERS_C99 || append!(hdrs, [
				"stdalign.h",
				"stdatomic.h",
				"stdnoreturn.h",
				"threads.h",
				"uchar.h",
			])
			
			ctx = ConverterContext(libs) do decl
				header = filename(decl)
				name   = spelling(decl)
				
				decl isa CLFunctionDecl && name in (
					"alloca",
					"atexit",
				) && return false
				
				startswith(name, "__") && (decl isa CLFunctionDecl || decl isa CLVarDecl || decl isa CLMacroDefinition) && return false
				
				return true
			end
			parse_headers!(ctx, hdrs, args = ["-std=$(VER)"], builtin = true)
			return ctx
		end
	end
end
