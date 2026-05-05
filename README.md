# StateMachines.jl

[action-img]: https://github.com/filipemlourenco/StateMachines.jl/workflows/CI/badge.svg
[action-url]: https://github.com/filipemlourenco/StateMachines.jl/actions

StateMachines is a Julia implementation of a [deterministic finite-state machine (DFSM)](https://en.wikipedia.org/wiki/Finite-state_machine). It can be used as a simple transition **state system**, as a business **workflow**, or as an autonomous **state machine**.

The implementation follows the DFA 5-tuple definition (Q, Σ, δ, q0, F):
- **Q** — finite set of states
- **Σ** — finite set of inputs (actions and context)
- **δ** — transition function (Q × Σ → Q)
- **q0** — initial state
- **F** — set of final (accept) states


## Setup

```julia
using Pkg; Pkg.add("StateMachines")
using StateMachines
```


## API Reference

### Transition

```julia
Transition(from, to)                        # unconditional transition
Transition(from, to, input::Symbol)         # fires on exact action match
Transition(from, to, input::Function)       # fires when input(action, context) == true
Transition(from, to, input, execute::Function)  # also calls execute(context) when fired
```

`from` and `to` are `State` (alias for `String`). When a transition fires, `execute` is called with the current `context` before the state changes — use it for side effects tied to a specific transition.

### Automaton

```julia
Automaton(transitions)
Automaton(transitions; start = "s0", states = [...], final = [...])
Automaton(transitions, start; final = [...])
Automaton(states, transitions, start; final = [...])
```

States are inferred from transitions when not provided explicitly. `start` defaults to the state of the first transition. `multistep` is enabled by default (see below).

### Execution

```julia
# Non-mutating — returns next state, does not change a.state
exec(a)                                            # advance from current state, no action
exec(a, action::Symbol; context, multistep)        # advance from current state with action
exec(a, s::State, action; context, multistep)      # advance from explicit state

# Mutating — advances and updates a.state, returns new state
exec!(a; context, multistep)
exec!(a, action::Symbol; context, multistep)
```

### Step mode

By default, after a transition fires `exec` keeps following unconditional transitions until the state stabilises (**multistep**). This lets you chain intermediate states transparently. Use `singlestep` to advance one transition at a time.

```julia
multistep!(a)              # enable (default)
singlestep!(a)             # disable

# or override per call:
exec(a, :action, multistep = false)
exec!(a, :action, multistep = true)
```

Multistep detects cycles (a state visited twice raises an error).

### Final states and getters

```julia
isfinal(a)             # true if current state is in final set
isfinal(a, s)          # true if s is in final set

StateMachines.states(a)           # all states
StateMachines.start(a)            # initial state
StateMachines.state(a)            # current state (also: current(a))
StateMachines.transitions(a)      # all transitions
StateMachines.transitions(a, s)   # transitions from state s
```


## Examples

### 1. Simple automaton

States and the initial state are inferred from the transition list.

```julia
a = Automaton([
    Transition("draft",    "prepared", :prepare),
    Transition("prepared", "reviewed", :review),
    Transition("prepared", "draft",    :reject),
])

# Pure query — reads a.state, does not mutate
StateMachines.exec(a, :prepare)   # => "prepared"

# Transition system — caller supplies the current state
StateMachines.exec(a, "draft", :prepare)   # => "prepared"

# Autonomous — advances and mutates a.state
StateMachines.exec!(a, :prepare)
a.state   # => "prepared"
```

### 2. Context-aware transitions

Pass arbitrary data as `context`; the guard function receives `(action, context)`.

```julia
workflow = Automaton([
    Transition("Draft",    "Prepared", :prepare),
    Transition("Prepared", "Reviewed", (action, ctx) -> action == :review && ctx.approved),
    Transition("Prepared", "Draft",    :reject),
    Transition("Reviewed", "Archived", :archive),
], final = ["Archived"])

record = (approved = true,)
StateMachines.exec(workflow, "Prepared", :review, context = record)   # => "Reviewed"

record2 = (approved = false,)
StateMachines.exec(workflow, "Prepared", :review, context = record2)  # => "Prepared" (no match)
```

### 3. Side effects with `execute`

The `execute` callback on a `Transition` fires with `context` when that transition is taken.

```julia
log = String[]

pipeline = Automaton([
    Transition("idle",     "running",  :start,    ctx -> push!(log, "started at $(ctx)")),
    Transition("running",  "done",     :finish,   ctx -> push!(log, "finished at $(ctx)")),
    Transition("running",  "failed",   :error,    ctx -> push!(log, "failed: $(ctx)")),
])

StateMachines.exec!(pipeline, :start,  context = "10:00")
StateMachines.exec!(pipeline, :finish, context = "10:05")

log   # => ["started at 10:00", "finished at 10:05"]
```

### 4. Multistep chaining

Unconditional transitions chain automatically in multistep mode. After the triggered transition fires, the automaton keeps following unconditional transitions until the state stabilises.

```julia
checkout = Automaton([
    Transition("new",        "processing", :submit),   # requires :submit action
    Transition("processing", "validated"),             # unconditional — chains automatically
    Transition("validated",  "complete"),              # unconditional — chains automatically
], final = ["complete"])

# :submit fires the first transition; the automaton then advances through
# "processing" and "validated" automatically and settles at "complete"
StateMachines.exec(checkout, "new", :submit)   # => "complete"

StateMachines.isfinal(checkout, "complete")    # => true
```
