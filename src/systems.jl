

system_headers(jl::Julia, tgt::Target{A, v, :linux, :gnu}, dist::Distro, lib::Library) where {A, v} = "/usr/include"
system_libraries(jl::Julia, tgt::Target{A, v, :linux, :gnu}, dist::Distro, lib::Library) where {A, v} = "/usr/lib"

