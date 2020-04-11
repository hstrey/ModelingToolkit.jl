"""
$(TYPEDEF)

A scalar equation for optimization.

# Fields
* `op` - The objective function

# Examples

```
@variables x y z
@parameters σ ρ β

op = σ*(y-x) + x*(ρ-z)-y + x*y - β*z
os = OptimizationSystem(eqs, [x,y,z],[σ,ρ,β])
```
"""
struct OptimizationSystem <: AbstractSystem
    """Vector of equations defining the system."""
    op::Operation
    """Unknown variables."""
    states::Vector{Variable}
    """Parameters."""
    ps::Vector{Variable}
    """
    Name: the name of the system
    """
    name::Symbol
    """
    systems: The internal systems
    """
    systems::Vector{OptimizationSystem}
end

function OptimizationSystem(op, states, ps;
                            name = gensym(:OptimizationSystem),
                            systems = OptimizationSystem[])
    OptimizationSystem(op, convert.(Variable,states), convert.(Variable,ps), name, systems)
end

function calculate_hessian(sys::OptimizationSystem)
    expand_derivatives.(hessian(equations(sys), [dv() for dv in states(sys)]))
end

function generate_hessian(sys::OptimizationSystem, vs = states(sys), ps = parameters(sys), expression = Val{true}; kwargs...)
    hes = calculate_hessian(sys)
    return build_function(hes, convert.(Variable,vs), convert.(Variable,ps), (), x->convert(Expr, x))
end

function generate_function(sys::OptimizationSystem, vs = states(sys), ps = parameters(sys), expression = Val{true}; kwargs...)
    vs′ = convert.(Variable,vs)
    ps′ = convert.(Variable,ps)
    return build_function(equations(sys), vs′, ps′, (), x->convert(Expr, x), expression; kwargs...)
end

equations(sys::OptimizationSystem) = isempty(sys.systems) ? sys.op : sys.op + reduce(+,namespace_operation.(sys.systems))
namespace_operation(sys::OptimizationSystem) = namespace_operation(sys.op,sys.name,nothing)