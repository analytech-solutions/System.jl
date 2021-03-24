module sys
	using System
	using System.CBinding
	
	
	export @sys, @c_cmd, @c_str, @pkgconf, @pkgconf_cmd
	
	
	macro pkgconf(exprs...) return pkgconf(__module__, __source__, exprs...) end
	
	function pkgconf(mod::Module, loc::LineNumberNode, expr::Expr)
		exprs = Base.is_expr(expr, :block) ? expr.args : [expr]
		
		deps    = []
		usings  = []
		cmds    = []
		strs    = []
		extras  = []
		for expr in exprs
			# TODO: handle predicated statements
			
			if Base.is_expr(expr, :using)
				for e in expr.args
					if Base.is_expr(e, :(:)) && length(e.args) >= 1
						e = e.args[1]
					end
					
					ind = 1
					while e.args[ind] == :.
						ind += 1
					end
					
					dep = nothing
					for ind in ind:length(e.args)
						dep = isnothing(dep) ? e.args[ind] : :($(dep).$(e.args[ind]))
						push!(usings, Expr(:import, Expr(:., e.args[1:ind]...)))
					end
					push!(deps, dep)
				end
				push!(usings, expr)
			elseif Base.is_expr(expr, :macrocall) && expr.args[1] == Symbol("@c_cmd")
				push!(cmds, expr)
			elseif Base.is_expr(expr, :macrocall) && expr.args[1] == Symbol("@pkgconf_cmd")
				push!(cmds, @eval @macroexpand1 $(expr))
			elseif Base.is_expr(expr, :macrocall) && expr.args[1] == Symbol("@c_str")
				push!(strs, expr)
			else
				push!(extras, esc(expr))
			end
		end
		
		
		flags = map(cmds) do cmd
			expr = :(``)
			expr.args[3] = cmd.args[3]
			return :($(esc(expr)).exec...)
		end
		
		prereqs = []
		ctx = :(``)
		ctx.args[1] = :($(CBinding).var"@c_cmd")
		for dep in deps
			push!(prereqs, :($(Expr(:$, :($(esc(dep))._DEFS...)))))
			ctx.args[3] *= " \$($(dep)._FLAGS)"
		end
		ctx.args[3] *= " \$(_FLAGS)"
		
		defs = map(strs) do str
			str = copy(str)
			length(str.args) < 4 && push!(str.args, "")
			str.args[4] = "s"
			return QuoteNode(str)
		end
		
		deps = map(esc, deps)
		
		return quote
			$(usings...)
			$(extras...)
			
			const $(esc(:_FLAGS)) = ($(flags...),)
			$(esc(ctx))
			
			@eval begin
				$(prereqs...)
				$(strs...)
			end
			const $(esc(:_DEFS))  = ($(defs...),)
		end
	end
	
	
	macro pkgconf_cmd(exprs...) return pkgconf_cmd(__module__, __source__, exprs...) end
	
	function pkgconf_cmd(mod::Module, loc::LineNumberNode, str::String, opts::String = "")
		opt = []
		'f' in opts && push!(opt, "--cflags")
		'l' in opts && push!(opt, "--libs")
		
		# TODO: handle spaces in paths, etc...
		flags = String(read(`pkg-config $(opt) $(str)`))
		
		expr = :(``)
		expr.args[1] = :($(CBinding).var"@c_cmd")
		expr.args[3] = flags
		return esc(expr)
	end
end
