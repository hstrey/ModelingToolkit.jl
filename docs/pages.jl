pages = [
    "Home" => "index.md",
    "tutorials/ode_modeling.md",
    "Tutorials" => Any["tutorials/acausal_components.md",
        "tutorials/nonlinear.md",
        "tutorials/optimization.md",
        "tutorials/modelingtoolkitize.md",
        "tutorials/stochastic_diffeq.md",
        "tutorials/parameter_identifiability.md"],
    "Examples" => Any["Basic Examples" => Any["examples/higher_order.md",
            "examples/spring_mass.md",
            "examples/modelingtoolkitize_index_reduction.md",
            "examples/parsing.md"],
        "Advanced Examples" => Any["examples/tearing_parallelism.md",
            "examples/sparse_jacobians.md",
            "examples/perturbation.md"]],
    "Basics" => Any["basics/AbstractSystem.md",
        "basics/ContextualVariables.md",
        "basics/Variable_metadata.md",
        "basics/Composition.md",
        "basics/Events.md",
        "basics/Linearization.md",
        "basics/Validation.md",
        "basics/DependencyGraphs.md",
        "basics/FAQ.md"],
    "System Types" => Any["systems/ODESystem.md",
        "systems/SDESystem.md",
        "systems/JumpSystem.md",
        "systems/NonlinearSystem.md",
        "systems/OptimizationSystem.md",
        "systems/DiscreteSystem.md",
        "systems/PDESystem.md"],
    "comparison.md",
    "internals.md",
]
