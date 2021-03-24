module libc
	const HEADERS = (;
		C89 = (
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
		),
		
		C95 = (
			:C89,
			"iso646.h",
			"wchar.h",
			"wctype.h",
		),
		
		C99 = (
			:C95,
			"fenv.h",
			"inttypes.h",
			"stdbool.h",
			"stdint.h",
			"tgmath.h",
		),
		
		C11 = (
			:C99,
			"stdalign.h",
			"stdatomic.h",
			"stdnoreturn.h",
			"threads.h",
			"uchar.h",
		),
		
		POSIX = (
			:C99,
			"aio.h",
			"arpa/inet.h",
			"complex.h",
			"cpio.h",
			"dirent.h",
			"dlfcn.h",
			"fcntl.h",
			"fmtmsg.h",
			"fnmatch.h",
			"ftw.h",
			"glob.h",
			"grp.h",
			"iconv.h",
			"langinfo.h",
			"libgen.h",
			"monetary.h",
			"mqueue.h",
			# "ndbm.h",
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
			"spawn.h",
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
			# "trace.h",
			"ulimit.h",
			"unistd.h",
			"utime.h",
			"utmpx.h",
			"wordexp.h",
		),
	)
	
	const ALIASES = (;
		C90 = :C89,
		C17 = :C11,
		
		GNU89 = :C89,
		GNU90 = :C90,
		GNU95 = :C95,
		GNU99 = :C99,
		GNU11 = :C11,
		GNU17 = :C17,
		
		C = :GNU17,
	)
	
	
	@eval export $(keys(HEADERS)...), $(keys(ALIASES)...)
	for std in keys(HEADERS)
		hdrs = HEADERS[std]
		hasmore = true
		while hasmore
			hasmore = false
			for ind in eachindex(hdrs)
				if hdrs[ind] isa Symbol
					hdrs = (hdrs[1:ind-1]..., HEADERS[hdrs[ind]]..., hdrs[ind+1:end]...)
					hasmore = true
					break
				end
			end
		end
		
		ctx = :(c``)
		if std === :POSIX
			ctx.args[3] = "-std=c99 -D_REENTRANT -D_POSIX_SOURCE -D_POSIX_C_SOURCE=200809L"
		else
			ctx.args[3] = "-std=$(lowercase(String(std)))"
		end
		
		bindings = :(c""Jcu)
		bindings.args[3] = join(map(hdr -> "#include <$(hdr)>", hdrs), '\n')
		
		try
			@eval module $(std)
				using sys
				
				@pkgconf begin
					$(ctx)
					$(bindings)
				end
			end
		catch
			std === :C11 || error("Headers for $(std) Standard Library not found")
		end
	end
	
	for std in keys(ALIASES)
		try
			@eval const $(std) = $(ALIASES[std])
		catch
		end
	end
end
