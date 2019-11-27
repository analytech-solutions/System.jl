
function Distro(::Julia, ::Target{A, v, :linux, :gnu}) where {A, v}
	id = :unknown
	ver = :unknown
	
	try
		open("/etc/os-release") do f
			for l in eachline(f)
				m = match(r"^\s*ID=(\S+)", strip(l))
				if !isnothing(m)
					id = Symbol(lowercase(strip(m.captures[1], '"')))
					continue
				end
				
				m = match(r"^\s*VERSION_ID=(\S+)", strip(l))
				if !isnothing(m)
					ver = Symbol(lowercase(strip(m.captures[1], '"')))
					continue
				end
			end
		end
	catch
	end
	
	return Distro{id, ver}()
end
