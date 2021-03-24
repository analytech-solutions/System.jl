using Test
using System


# NOTE: tests require certain headers and libraries to be installed
#       reference `System.jl/.github/workflows/CI.yml` for commands


@testset "System.jl" begin
	@test @eval begin
		@sys using sys
		true
	end
	
	
	@test @eval begin
		@sys using libc
		true
	end
	
	
	if Sys.islinux()
		@test @eval begin
			@sys using linux
			true
		end
		
		@test @eval begin
			@sys using alsa
			true
		end
	end
end

