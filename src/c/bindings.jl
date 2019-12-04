

const LIBS = (:libc,)

const VERS_C90 = (:c89, :c90, :gnu89, :gnu90,)
const VERS_C99 = (:c99, :gnu99,)
const VERS_C11 = (:c11, :gnu11,)
const VERS_C18 = (:c17, :c18, :gnu17, :gnu18,)
const VERS = (VERS_C90..., VERS_C99..., VERS_C11..., VERS_C18...)

# bindings for generic Linux systems (POSIX C)
for LIB in LIBS
	SystemBindings.Library{LIB}(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = Library{LIB, :gnu99}(tgt, dist)
	
	for VER in VERS
		SystemBindings.Library{LIB, VER}(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = Library{LIB, VER}()
		
		SystemBindings.Binding(tgt::Target{A, v, :linux, :gnu}, dist::Distro, lib::Library{LIB, VER}) where {A, v} = Binding{typeof(lib)}(Binding[], joinpath(@__DIR__, "atcompile.jl"), nothing) do
			libs = [
				_find_library("libc.so.6"),
				_find_library("libm.so.6"),
				_find_library("libpthread.so.0"),
				_find_library("libdl.so.2"),
				_find_library("librt.so.1"),
				#_find_library("libutil.so.1"),
				#_find_library("libresolv.so.2"),
				#_find_library("libcrypt.so.1"),
				# TODO: libanl, libnsl, libcidn, etc...
			]
			
			# C headers
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
			
			# POSIX C headers:  https://pubs.opengroup.org/onlinepubs/9699919799/idx/head.html
			VER in VERS_C90 || append!(hdrs, [
				"aio.h",
				"arpa/inet.h",
				"assert.h",
				"complex.h",
				"cpio.h",
				"ctype.h",
				"dirent.h",
				"dlfcn.h",
				"errno.h",
				"fcntl.h",
				"fenv.h",
				"float.h",
				"fmtmsg.h",
				"fnmatch.h",
				"ftw.h",
				"glob.h",
				"grp.h",
				"iconv.h",
				"inttypes.h",
				"iso646.h",
				"langinfo.h",
				"libgen.h",
				"limits.h",
				"locale.h",
				"math.h",
				"monetary.h",
				"mqueue.h",
				"ndbm.h",
				"net/if.h",
				"netdb.h",
				"netinet/in.h",
				"netinet/tcp.h",
				"nl_types.h",
				"poll.h",
				"pthread.h",
				"pwd.h",
				"regex.h",
				"sched.h",
				"search.h",
				"semaphore.h",
				"setjmp.h",
				"signal.h",
				"spawn.h",
				"stdarg.h",
				"stdbool.h",
				"stddef.h",
				"stdint.h",
				"stdio.h",
				"stdlib.h",
				"string.h",
				"strings.h",
				# "stropts.h",
				"sys/ipc.h",
				"sys/mman.h",
				"sys/msg.h",
				"sys/resource.h",
				"sys/select.h",
				"sys/sem.h",
				"sys/shm.h",
				"sys/socket.h",
				"sys/stat.h",
				"sys/statvfs.h",
				"sys/time.h",
				"sys/times.h",
				"sys/types.h",
				"sys/uio.h",
				"sys/un.h",
				"sys/utsname.h",
				"sys/wait.h",
				"syslog.h",
				"tar.h",
				"termios.h",
				"tgmath.h",
				"time.h",
				# "trace.h",
				"ulimit.h",
				"unistd.h",
				"utime.h",
				"utmpx.h",
				"wchar.h",
				"wctype.h",
				"wordexp.h",
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
			parse_headers!(ctx, hdrs, args = ["-std=$(VER)"], builtin = true)
			return ctx
		end
	end
end

function _find_library(file::String)
	lib = mapreduce(dir -> joinpath(dir, file), (l, r) -> isfile(l) ? l : r, system_libraries())
	isfile(lib) || error("Library $(file) was not found in the system library locations: $(system_libraries())")
	return lib
end
