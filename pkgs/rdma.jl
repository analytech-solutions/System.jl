module rdma
	export libibverbs, librdmacm
	
	
	module libibverbs
		using sys
		
		@pkgconf begin
			using libc.POSIX, linux
			
			c`-libverbs`
			c"""
				#include <infiniband/verbs.h>
			"""jiw
		end
		
		function __init__()
			ENV["IBV_FORK_SAFE"] = "1"
		end
	end
	
	
	module librdmacm
		using sys
		
		@pkgconf begin
			using libc.POSIX, linux, ..libibverbs
			
			c`-lrdmacm`
			c"""
				#include <rdma/rdma_verbs.h>
			"""ji
		end
		
		function __init__()
			ENV["RDMAV_FORK_SAFE"] = "1"
		end
	end
end
