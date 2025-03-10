##### Numeric simplification

"""
```julia
simplify(x; expand=false,
            threaded=false,
            thread_subtree_cutoff=100,
            rewriter=nothing)
```

Simplify an expression (`x`) by applying `rewriter` until there are no changes.
`expand=true` applies [`expand`](/api/#expand) in the beginning of each fixpoint iteration.
"""
function simplify(x;
                  expand=false,
                  polynorm=nothing,
                  threaded=false,
                  thread_subtree_cutoff=100,
                  rewriter=nothing)
    if polynorm !== nothing
        Base.depwarn("simplify(..; polynorm=$polynorm) is deprecated, use simplify(..; expand=$polynorm) instead",
                        :simplify)
    end

    f = if rewriter === nothing
        if threaded
            threaded_simplifier(thread_subtree_cutoff)
        elseif expand
            serial_expand_simplifier
        else
            serial_simplifier
        end
    else
        Fixpoint(rewriter)
    end

    PassThrough(f)(x)
end

Base.@deprecate simplify(x, ctx; kwargs...)  simplify(x; rewriter=ctx, kwargs...)

"""
    substitute(expr, dict)

substitute any subexpression that matches a key in `dict` with
the corresponding value.
"""
function substitute(expr, dict; fold=true)
    haskey(dict, expr) && return dict[expr]

    if istree(expr)
        if fold
            canfold=true
            args = map(arguments(expr)) do x
                x′ = substitute(x, dict; fold=fold)
                canfold = canfold && !(x′ isa Symbolic)
                x′
            end
            canfold && return operation(expr)(args...)
            args
        else
            args = map(x->substitute(x, dict), arguments(expr))
        end
        similarterm(expr, operation(expr), args, metadata=metadata(expr))
    else
        expr
    end
end

"""
    occursin(needle::Symbolic, haystack::Symbolic)

Determine whether the second argument contains the first argument. Note that
this function doesn't handle associativity, commutativity, or distributivity.
"""
Base.occursin(needle::Symbolic, haystack::Symbolic) = _occursin(needle, haystack)
Base.occursin(needle, haystack::Symbolic) = _occursin(needle, haystack)
Base.occursin(needle::Symbolic, haystack) = _occursin(needle, haystack)
function _occursin(needle, haystack)
    isequal(needle, haystack) && return true

    if istree(haystack)
        args = arguments(haystack)
        for arg in args
            occursin(needle, arg) && return true
        end
    end
    return false
end
