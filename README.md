# StateMachines.jl

[action-img]: https://github.com/filipemlourenco/StateMachines.jl/workflows/CI/badge.svg
[action-url]: https://github.com/filipemlourenco/StateMachines.jl/actions

StateMachines package is functional implementation of a [deterministic finite-state machine (DFSM)](https://en.wikipedia.org/wiki/Finite-state_machine) - also known as a [deterministic finite automaton (DFA)](https://en.wikipedia.org/wiki/Deterministic_finite_automaton). It can be used as a simple transition **state system**, as a business **workflow** or as a autonomous **state machine**.

Implementation follows the definition of a deterministic finite automaton M that is a 5-tuple, (Q, Σ, δ, q0, F), consisting of:
- a finite set of **states** (Q)
- a finite set of inputs - **actions and context** (Σ)
- a finite set of **transitions** or transition function (d: Q x Σ -> δ)
- an **initial** or start state (q[0])
- a set of **accept** or final states (F)


## Setup

```julia
using Pkg; Pkg.add("StateMachines");
using StateMachines
```

## Usage

1. Create an automaton (`Automaton`)
2. Execute the automaton (`exec` or `exec!`)


### Syntax
Automaton instatiation:
```julia
t = Transition(from::State, to::State)
t = Transition(from::State, to::State, input::Symbol)
t = Transition(from::State, to::State, input::Function)

a = Automaton(ts::Vector{Transition})
a = Automaton(states::Vector{State}, ts::Vector{Transition})
a = Automaton(states::Vector{State}, ts::Vector{Transition}, start::State)
```

Automaton execution:
```julia
exec!(a::Automaton; context::Any = nothing; multistep::Union{Bool, Nothing} = nothing)
exec!(a::Automaton, action::Symbol; context::Any = nothing; multistep::Union{Bool, Nothing} = nothing)

a1 = exec(a::Automaton; context::Any = nothing; multistep::Union{Bool, Nothing} = nothing)
a1 = exec(a::Automaton, action::Symbol; context::Any = nothing; multistep::Union{Bool, Nothing} = nothing)
a1 = exec(a::Automaton, s::State, action::Union{Symbol, Nothing}; context::Any = nothing; multistep::Union{Bool, Nothing} = nothing)
```


### 1. Simple example

Create an automaton with only the transitions states. Initial state will be the state from the first transition and no final stage will be set. Accepted states and inputs (actions) will be infeered from the transitions.

#### Automaton Instantiation
```julia
    a1 = Automaton([
        Transition(State("s1"), State("s2"), :create),
        Transition(State("s2"), State("s3")),
        Transition(State("s1"), State("s4"), :update),
    ])
```

or (states can be replaced by a string)

```julia
    a1 = Automaton([
        Transition("s1", "s2", :create),
        Transition("s2", "s3"),
        Transition("s1", "s4", :update),
    ])
```

or (instantiation with acceptable state list and initial state)
```julia
    a1 = Automaton([Transition("s1", "s2", :create), Transition("s1", "s4", :update)],
        states = ["s1", "s2", "s3", "s4"],
        start  = "s1"
    )
```

#### Automaton Execution

Simple automaton execution:
```julia
next_state = StateMachines.exec(a1, :create)
```

Automaton execution as a transition system (e.g. workflow):
```julia
current_state = State("s1")
next_state = StateMachines.exec(a1, current_state, :create)
```

Automaton execution as a self (or autonomous) state machine:
```julia
StateMachines.exec!(a1, :update)
```

### 2. Business workflow example

```julia
workflow = Automaton([
    Transition("Draft",    "Prepared",  :prepare),
    Transition("Prepared", "Reviewed",  (action, context) -> action == :review && context.var1 == 0),
    Transition("Prepared", "Draft",     :update),
    Transition("Reviewed", "Archived",  :archive),
    Transition("Reviewed", "Draft",     :update),
])

record = (name = "my business record", state = "Draft", var1 = 1, var2 = 2)

new_state = StateMachines.exec(workflow, record.state, :prepare, context = record, multistep = true)
```
