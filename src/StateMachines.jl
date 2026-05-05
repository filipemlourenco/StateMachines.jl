module StateMachines

export State
export Transition
export Automaton

# --- Models
struct State
    name :: String
end

Base.:(==)(a::State, b::State)  = a.name == b.name
Base.:(==)(a::State, b::String) = a.name == b
Base.:(==)(a::String, b::State) = a == b.name
Base.hash(s::State, h::UInt)    = hash(s.name, h)
Base.show(io::IO, s::State)     = print(io, s.name)
Base.string(s::State)           = s.name
Base.convert(::Type{State}, s::AbstractString) = State(String(s))
Base.convert(::Type{State}, s::State)          = s
Base.convert(::Type{String}, s::State)         = s.name

struct Transition
    from    :: State
    to      :: State
    input   :: Union{Nothing, Symbol, Function}
    execute :: Union{Nothing, Function}
end
Transition(from::State, to::State)              = Transition(from, to, nothing, nothing)
Transition(from::State, to::State, input)       = Transition(from, to, input,   nothing)

Transition(from::AbstractString, to::AbstractString)              = Transition(State(from), State(to), nothing, nothing)
Transition(from::AbstractString, to::AbstractString, input)       = Transition(State(from), State(to), input,   nothing)
Transition(from::AbstractString, to::AbstractString, input, exec) = Transition(State(from), State(to), input,   exec)

function Base.show(io::IO, t::Transition)
    input_str = isnothing(t.input) ? "" : " input=$(t.input isa Function ? "Function" : repr(t.input))"
    exec_str  = isnothing(t.execute) ? "" : ", execute=Function"
    print(io, "Transition($(t.from) → $(t.to)$(input_str)$(exec_str))")
end

function _build_lookup(transitions::Vector)
    lookup = Dict{State, Vector{Transition}}()
    for t in transitions
        push!(get!(Vector{Transition}, lookup, t.from), t)
    end
    return lookup
end

function _check_duplicate_inputs(transitions::Vector)
    by_state = Dict{State, Vector}()
    for t in transitions
        push!(get!(Vector, by_state, t.from), t.input)
    end
    for (s, inputs) in by_state
        symbol_inputs = filter(x -> x isa Symbol || isnothing(x), inputs)
        if length(symbol_inputs) != length(unique(symbol_inputs))
            @warn "state $s has duplicate transition inputs; only the first matching transition will be used"
        end
    end
end

mutable struct Automaton
    states      :: Vector{State}
    transitions :: Vector{Transition}
    start       :: State
    final       :: Vector{State}

    state       :: State
    multistep   :: Bool
    _lookup     :: Dict{State, Vector{Transition}}

    function Automaton(states::Vector, transitions::Vector, start::Union{AbstractString, State, Nothing} = nothing; final::Vector = [])
        states = State.(states)
        final  = State.(final)

        @assert length(states) > 1 "Automaton requires at least 2 states, got $(length(states))"
        @assert !isempty(transitions) "Automaton should have at least one transition"

        start = isnothing(start) ? states[1] : convert(State, start)
        @assert start in states "'$start' state not present in the states list"

        ts = unique(vcat(map(x -> x.from, transitions), map(x -> x.to, transitions)))
        invalid_states = setdiff(ts, states)
        @assert isempty(invalid_states) "Invalid state(s) in transitions: $(join(invalid_states, ", ")). Available states: $(join(states, ", "))"
        invalid_final = setdiff(final, states)
        @assert isempty(invalid_final) "Invalid final state(s): $(join(invalid_final, ", ")). Available states: $(join(states, ", "))"

        _check_duplicate_inputs(transitions)

        return new(states, transitions, start, final, start, true, _build_lookup(transitions))
    end

    function Automaton(transitions::Vector, start::Union{AbstractString, State}; final::Vector = [])
        states = unique(vcat(map(x -> x.from, transitions), map(x -> x.to, transitions)))
        return Automaton(states, transitions, start, final = final)
    end

    function Automaton(transitions::Vector; states::Vector = [], start::Union{AbstractString, State, Nothing} = nothing, final::Vector = [])
        _states = isempty(states) ? unique(vcat(map(x -> x.from, transitions), map(x -> x.to, transitions))) : states
        return Automaton(_states, transitions, start, final = final)
    end
end

function Base.show(io::IO, w::Automaton)
    println(io, "Automaton:")
    println(io, "  States ($(length(w.states))): ", join(w.states, ", "))
    println(io, "  Start: ", w.start)
    println(io, "  Current: ", w.state)
    if !isempty(w.final)
        println(io, "  Final: ", join(w.final, ", "))
    end
    println(io, "  Multistep: ", w.multistep)
    println(io, "  Transitions ($(length(w.transitions))):")
    for t in w.transitions
        print(io, "    ")
        show(io, t)
        println(io)
    end
end

# --- Getters
states(w::Automaton)    = w.states
start(w::Automaton)     = w.start
state(w::Automaton)     = w.state
current(w::Automaton)   = w.state
transitions(w::Automaton) = w.transitions
transitions(w::Automaton, s::State)          = get(w._lookup, s, Transition[])
transitions(w::Automaton, s::AbstractString) = transitions(w, State(s))

# --- Final states
isfinal(w::Automaton) = w.state in w.final
isfinal(w::Automaton, s::State)          = s in w.final
isfinal(w::Automaton, s::AbstractString) = isfinal(w, State(s))

# --- Setters
multistep!(w::Automaton)    = (w.multistep = true)
singlestep!(w::Automaton)   = (w.multistep = false)

# --- Automaton (state machine) execution
function exec!(w::Automaton, action::Union{Symbol, Nothing} = nothing; context::Any = nothing, multistep::Union{Bool, Nothing} = nothing)
    w.state = exec(w, w.state, action, context = context, multistep = multistep)
end

exec(w::Automaton; context::Any = nothing, multistep::Union{Bool, Nothing} = nothing) =
    exec(w, w.state, nothing, context = context, multistep = multistep)

exec(w::Automaton, action::Symbol; context::Any = nothing, multistep::Union{Bool, Nothing} = nothing) =
    exec(w, w.state, action,  context = context, multistep = multistep)

exec(w::Automaton, s::AbstractString, action::Union{Symbol, Nothing} = nothing; context::Any = nothing, multistep::Union{Bool, Nothing} = nothing) =
    exec(w, State(s), action, context = context, multistep = multistep)

function exec(w::Automaton, s::State, action::Union{Symbol, Nothing} = nothing; context::Any = nothing, multistep::Union{Bool, Nothing} = nothing) :: State
    @assert s in w.states "State not available in the automaton ($s)"

    _multistep = isnothing(multistep) ? w.multistep : multistep
    prev = s
    n = _exec(w, prev, action, context = context)
    if _multistep
        visited = [s]
        while prev != n
            n in visited && error("Cycle detected in multistep execution: reached '$n' again. Visited: $(join(visited, " → "))")
            push!(visited, n)
            prev = n
            n = _exec(w, prev, nothing, context = context)
        end
    end

    return n
end

function _exec(w::Automaton, s::State, action::Union{Symbol, Nothing}; context::Any = nothing) :: State
    trans = get(w._lookup, s, [])
    for t in trans
        if isnothing(t.input) ||
            (t.input isa Symbol && t.input == action) ||
            (t.input isa Function && t.input(action, context))
                if !isnothing(t.execute)
                    t.execute(context)
                end
                return t.to
        end
    end
    return s
end

end # module StateMachines
