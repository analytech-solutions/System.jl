
function Target(::Julia{1, m, p}) where {m, p}
	(arch, ven, sys, abi) = map(Symbol, split(lowercase(Base.MACHINE), '-'))
	return Target{arch, ven, sys, abi}()
end

