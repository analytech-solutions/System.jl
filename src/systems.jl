

system_headers(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = "/usr/include"
system_libraries(tgt::Target{A, v, :linux, :gnu}, dist::Distro) where {A, v} = "/usr/lib"

