module alsa
	module libasound
		using sys
		
		@pkgconf begin
			using libc.POSIX
			
			c`-lasound`
			c"""
				#include <alsa/asoundlib.h>
			"""ji
		end
	end
end
