using ModelingToolkit
using ModelingToolkit: t_nounits as t, D_nounits as D, MTKParameters
using SymbolicIndexingInterface
using SciMLStructures: SciMLStructures, canonicalize, Tunable, Discrete, Constants
using OrdinaryDiffEq
using ForwardDiff

@parameters a b c d::Integer e[1:3] f[1:3, 1:3]::Int g::Vector{AbstractFloat} h::String
@named sys = ODESystem(
    Equation[], t, [], [a, c, d, e, f, g, h], parameter_dependencies = [b => 2a],
    continuous_events = [[a ~ 0] => [c ~ 0]], defaults = Dict(a => 0.0))
sys = complete(sys)

ivs = Dict(c => 3a, d => 4, e => [5.0, 6.0, 7.0],
    f => ones(Int, 3, 3), g => [0.1, 0.2, 0.3], h => "foo")

ps = MTKParameters(sys, ivs)
@test_nowarn copy(ps)
# dependent initialization, also using defaults
@test getp(sys, a)(ps) == getp(sys, b)(ps) == getp(sys, c)(ps) == 0.0
@test getp(sys, d)(ps) isa Int

ivs[a] = 1.0
ps = MTKParameters(sys, ivs)
@test_broken getp(sys, g) # SII bug
for (p, val) in ivs
    isequal(p, g) && continue # broken
    if isequal(p, c)
        val = 3ivs[a]
    end
    idx = parameter_index(sys, p)
    # ensure getindex with `ParameterIndex` works
    @test ps[idx] == getp(sys, p)(ps) == val
end

# ensure setindex! with `ParameterIndex` works
ps[parameter_index(sys, a)] = 3.0
@test getp(sys, a)(ps) == 3.0
setp(sys, a)(ps, 1.0)

@test getp(sys, a)(ps) == getp(sys, b)(ps) / 2 == getp(sys, c)(ps) / 3 == 1.0

for (portion, values) in [(Tunable(), vcat(ones(9), [1.0, 4.0, 5.0, 6.0, 7.0]))
                          (Discrete(), [3.0])
                          (Constants(), [0.1, 0.2, 0.3])]
    buffer, repack, alias = canonicalize(portion, ps)
    @test alias
    @test sort(collect(buffer)) == values
    @test all(isone,
        canonicalize(portion, SciMLStructures.replace(portion, ps, ones(length(buffer))))[1])
    # make sure it is out-of-place
    @test sort(collect(buffer)) == values
    SciMLStructures.replace!(portion, ps, ones(length(buffer)))
    # make sure it is in-place
    @test all(isone, canonicalize(portion, ps)[1])
    repack(zeros(length(buffer)))
    @test all(iszero, canonicalize(portion, ps)[1])
end

setp(sys, a)(ps, 2.0) # test set_parameter!
@test getp(sys, a)(ps) == 2.0

setp(sys, e)(ps, 5ones(3)) # with an array
@test getp(sys, e)(ps) == 5ones(3)

setp(sys, f[2, 2])(ps, 42) # with a sub-index
@test getp(sys, f[2, 2])(ps) == 42

# SII bug
@test_broken setp(sys, g)(ps, ones(100)) # with non-fixed-length array
@test_broken getp(sys, g)(ps) == ones(100)

setp(sys, h)(ps, "bar") # with a non-numeric
@test getp(sys, h)(ps) == "bar"

newps = remake_buffer(sys,
    ps,
    Dict(a => 1.0f0, b => 5.0f0, c => 2.0, d => 0x5, e => [0.4, 0.5, 0.6],
        f => 3ones(UInt, 3, 3), g => ones(Float32, 4), h => "bar"))

for fname in (:tunable, :discrete, :constant, :dependent)
    # ensure same number of sub-buffers
    @test length(getfield(ps, fname)) == length(getfield(newps, fname))
end
@test ps.dependent_update_iip === newps.dependent_update_iip
@test ps.dependent_update_oop === newps.dependent_update_oop

@test getp(sys, a)(newps) isa Float32
@test getp(sys, b)(newps) == 2.0f0 # ensure dependent update still happened, despite explicit value
@test getp(sys, c)(newps) isa Float64
@test getp(sys, d)(newps) isa UInt8
@test getp(sys, f)(newps) isa Matrix{UInt}
# SII bug
@test_broken getp(sys, g)(newps) isa Vector{Float32}

ps = MTKParameters(sys, ivs)
function loss(value, sys, ps)
    @test value isa ForwardDiff.Dual
    vals = merge(Dict(parameters(sys) .=> getp(sys, parameters(sys))(ps)), Dict(a => value))
    ps = remake_buffer(sys, ps, vals)
    getp(sys, a)(ps) + getp(sys, b)(ps)
end

@test ForwardDiff.derivative(x -> loss(x, sys, ps), 1.5) == 3.0

# Issue#2615
@parameters p::Vector{Float64}
@variables X(t)
eq = D(X) ~ p[1] - p[2] * X
@mtkbuild osys = ODESystem([eq], t)

u0 = [X => 1.0]
ps = [p => [2.0, 0.1]]
p = MTKParameters(osys, ps, u0)
@test p.tunable[1] == [2.0, 0.1]

# Ensure partial update promotes the buffer
@parameters p q r
@named sys = ODESystem(Equation[], t, [], [p, q, r])
sys = complete(sys)
ps = MTKParameters(sys, [p => 1.0, q => 2.0, r => 3.0])
newps = remake_buffer(sys, ps, Dict(p => 1.0f0))
@test newps.tunable[1] isa Vector{Float32}
@test newps.tunable[1] == [1.0f0, 2.0f0, 3.0f0]

# Issue#2624
@parameters p d
@variables X(t)
eqs = [D(X) ~ p - d * X]
@mtkbuild sys = ODESystem(eqs, t)

u0 = [X => 1.0]
tspan = (0.0, 100.0)
ps = [p => 1.0] # Value for `d` is missing

@test_throws ModelingToolkit.MissingVariablesError ODEProblem(sys, u0, tspan, ps)
@test_nowarn ODEProblem(sys, u0, tspan, [ps..., d => 1.0])

# Issue#2642
@parameters α β γ δ
@variables x(t) y(t)
eqs = [D(x) ~ (α - β * y) * x
       D(y) ~ (δ * x - γ) * y]
@mtkbuild odesys = ODESystem(eqs, t)
odeprob = ODEProblem(
    odesys, [x => 1.0, y => 1.0], (0.0, 10.0), [α => 1.5, β => 1.0, γ => 3.0, δ => 1.0])
tunables, _... = canonicalize(Tunable(), odeprob.p)
@test tunables isa AbstractVector{Float64}

function loss(x)
    ps = odeprob.p
    newps = SciMLStructures.replace(Tunable(), ps, x)
    newprob = remake(odeprob, p = newps)
    sol = solve(newprob, Tsit5())
    return sum(sol)
end

@test_nowarn ForwardDiff.gradient(loss, collect(tunables))
