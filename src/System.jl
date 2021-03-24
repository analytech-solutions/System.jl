module System
	using CBinding
	
	
	export @sys
	export @c_str, isqualifiedwith, unqualifiedtype, bitstype
	
	
	macro sys(exprs...) return sys(__module__, __source__, exprs...) end
	
	function sys(mod::Module, loc::LineNumberNode, expr::Expr)
		Base.is_expr(expr, :using, 1) || Base.is_expr(expr, :import, 1) || error("Expected a `using ...` or `import ...` statement in @sys usage")
		
		path = expr.args[1]
		if Base.is_expr(path, :(:)) && length(path.args) >= 1
			path = path.args[1]
		end
		name = path.args[1]
		
		sym = gensym(name)
		pushfirst!(path.args, :Base, :Main, sym)
		
		return quote
			@eval Base.Main module $(sym)
				import $(name)
			end
			$(expr)
		end
	end
	
	
	function __init__()
		push!(Base.LOAD_PATH, joinpath(dirname(@__DIR__), "pkgs"))
	end
end

