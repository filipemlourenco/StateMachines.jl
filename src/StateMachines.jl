module StateMachines

export State
export Transition
export Automaton

MULTISTEP = true

# --- Models
const State = String

struct Transition
    from        :: State
    to          :: State
    input       :: Union{Nothing, Symbol, Function}
end
Transition(from::State, to::State) = Transition(from, to, nothing)

mutable struct Automaton
    states      :: Vector{State}
    transitions :: Vector{Transition}
    start       :: Union{Nothing, State}

    state     :: State

    function Automaton(states::Vector, transitions::Vector, start::Union{Nothing, State} = nothing)
        @assert length(states) > 1 "Automaton should have at least two elements"
        @assert !isempty(transitions) "Automaton should have at least one transition"

        start = isnothing(start) ? states[1] : start
        @assert start in states "'$start' state not present in the states list"

        return new(states, transitions, start, start)
    end

    function Automaton(transitions::Vector, start::Union{Nothing, State} = nothing)
        states = unique([map(x -> x.from, transitions)..., map(x -> x.to, transitions)...])
        return Automaton(states, transitions, start)
    end
end

# --- Getters
states(w::Automaton)    = w.states
start(w::Automaton)     = w.start
state(w::Automaton)     = w.state
current(w::Automaton)   = w.state
transitions(w::Automaton) :: Vector = [(k => n.to) for (k,v) in w.transitions, n in v]
transitions(w::Automaton, s::State) :: Vector = [t.to for t in w[s].transitions]

# --- Setters
multistep!()    = (global MULTISTEP = true)
singlestep!()   = (global MULTISTEP = false)

# --- Automaton (state machine) execution
function exec!(w::Automaton, action::Union{Symbol, Nothing} = nothing; context::Any = nothing)
    w.state = exec(w, w.state, action, context = context)
end

exec(w::Automaton; context::Any = nothing)                  = exec(w, w.state, nothing, context = context)
exec(w::Automaton, action::Symbol; context::Any = nothing)  = exec(w, w.state, action,  context = context)
function exec(w::Automaton, s::State, action::Union{Symbol, Nothing} = nothing; context::Any = nothing) :: State
    @assert s in w.states "State not available in the automaton ($s)"

    prev = s
    n = _exec(w, prev, action, context = context)
    if MULTISTEP
        while(prev != n)
            prev = n
            n = _exec(w, prev, nothing, context = context)
        end
    end

    return n
end

function _exec(w::Automaton, s::State, action::Union{Symbol, Nothing}; context::Any = nothing) :: State
    trans = filter(x -> x.from == s, w.transitions) 
    for t in trans
        if isnothing(t.input) ||
            (t.input isa Symbol && t.input == action) ||
            (t.input isa Function && t.input(action, context))
                return t.to
        end
    end
    return s
end

end # module StateMachines