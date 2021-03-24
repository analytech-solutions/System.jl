module linux
	using sys
	
	@pkgconf begin
		using libc.POSIX
		
		c``
		c"""
			#include <asm-generic/types.h>
			#include <asm/types.h>
			#include <linux/types.h>
			// add other linux/*.h here...
		"""ji
	end
end
