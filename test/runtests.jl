using StateMachines
using Test

@testset verbose = true "StateMachines tests" begin

@testset "Object instantiation" begin

    @test State("test") == "test"

    @test Transition(State("from"), State("to")).from == "from"
    @test Transition(State("from"), State("to")).to == "to"
    @test Transition(State("from"), State("to")).input === nothing
    @test Transition(State("from"), State("to")).execute === nothing
    @test Transition(State("from"), State("to"), :write).input == :write
    @test Transition(State("from"), State("to"), :write).execute === nothing
    t4 = Transition(State("from"), State("to"), :write, ctx -> ctx)
    @test t4.input == :write
    @test t4.execute isa Function

    a = Automaton(
        [State("1"), State("2"), State("3"), State("4"), State("5"), State("6")],
        [
            Transition(State("1"), State("2"))
            Transition(State("2"), State("3"))
            Transition(State("3"), State("4"))
        ],
        State("2")
    )

    @test a.start == "2"
    @test a.start isa State
    @test a.state == "2"
    @test length(a.transitions) == 3
    @test a.states == ["1", "2", "3", "4", "5", "6"]

    b = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("3"))
    ])

    @test b.start == "1"
    @test length(b.transitions) == 2
    @test b.states == ["1", "2", "3"]

    c = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("3"))
    ], start = "2")
    @test c.start == "2"

    # 2-arg positional start
    d = Automaton([Transition(State("1"), State("2")), Transition(State("2"), State("3"))], "2")
    @test d.start == "2"
    @test d.state == "2"

    # final keyword
    e = Automaton([Transition(State("1"), State("2"))], final = ["2"])
    @test e.final == ["2"]

    # construction with explicit states and final
    f = Automaton(
        [State("1"), State("2"), State("3")],
        [Transition(State("1"), State("2")), Transition(State("2"), State("3"))],
        State("1"),
        final = ["3"]
    )
    @test f.final == ["3"]

    @test_throws AssertionError Automaton([])

    # transition references state not in explicit states list
    @test_throws AssertionError Automaton(
        [State("1"), State("2"), State("3")],
        [
            Transition(State("1"), State("2"))
            Transition(State("2"), State("4"))
        ],
        State("2")
    )

    # start state not in states list
    @test_throws AssertionError Automaton(
        [State("1"), State("2")],
        [Transition(State("1"), State("2"))],
        State("99")
    )

    # single-state automaton (requires at least 2 states)
    @test_throws AssertionError Automaton(
        [State("1")],
        [Transition(State("1"), State("1"))]
    )

    # final state not in states list
    @test_throws AssertionError Automaton(
        [Transition(State("1"), State("2"))],
        final = ["99"]
    )

    # invalid start type rejected at the call boundary
    # positional → MethodError (no matching dispatch); keyword → TypeError (type annotation violated)
    @test_throws MethodError Automaton([Transition(State("1"), State("2"))], 42)
    @test_throws TypeError    Automaton([Transition(State("1"), State("2"))]; start = 42)

    # string-based constructors and state dispatch
    g = Automaton([
        Transition("1", "2", :go)
        Transition("2", "3")
    ])
    @test StateMachines.exec(g, "1", :go) == "3"

    h = Automaton([
        Transition("1", "2")
        Transition("2", "3")
    ], "2")
    @test h.start == "2"
    @test h.state == "2"
    @test h.states == ["1", "2", "3"]

    # check assertion error message contents
    err1 = try
        Automaton([State("1")], [Transition(State("1"), State("1"))])
        nothing
    catch e
        e
    end
    @test isa(err1, AssertionError)
    @test occursin("requires at least 2 states", string(err1))

    err2 = try
        Automaton(
            [State("1"), State("2"), State("3")],
            [Transition(State("1"), State("2")), Transition(State("2"), State("4"))],
            State("2")
        )
        nothing
    catch e
        e
    end
    @test isa(err2, AssertionError)
    @test occursin("Invalid state(s) in transitions", string(err2))

    err3 = try
        Automaton([Transition(State("1"), State("2"))], final = ["99"])
        nothing
    catch e
        e
    end
    @test isa(err3, AssertionError)
    @test occursin("Invalid final state(s)", string(err3))

end

@testset "Duplicate input warning" begin

    @test_logs (:warn, r"duplicate") Automaton([
        Transition(State("1"), State("2"), :go)
        Transition(State("1"), State("3"), :go)
        Transition(State("3"), State("2"))
    ])

    # duplicate nothing (unconditional) inputs also warn
    @test_logs (:warn, r"duplicate") Automaton([
        Transition(State("1"), State("2"))
        Transition(State("1"), State("3"))
        Transition(State("3"), State("2"), :done)
    ])

    # function inputs alongside symbols do not warn
    @test_logs Automaton([
        Transition(State("1"), State("2"), :go)
        Transition(State("1"), State("3"), (a, _) -> a == :other)
        Transition(State("3"), State("2"))
    ])

end

@testset "Getters" begin

    a = Automaton(
        [State("1"), State("2"), State("3")],
        [Transition(State("1"), State("2"), :go), Transition(State("2"), State("3"))],
        State("1"),
        final = ["3"]
    )

    @test StateMachines.states(a) == ["1", "2", "3"]
    @test StateMachines.start(a) == "1"
    @test StateMachines.state(a) == "1"
    @test StateMachines.current(a) == "1"

    @test length(StateMachines.transitions(a)) == 2
    @test StateMachines.transitions(a, "1")[1].to == "2"
    @test length(StateMachines.transitions(a, "1")) == 1
    @test StateMachines.transitions(a, "2")[1].to == "3"
    @test StateMachines.transitions(a, "nonexistent") == Transition[]

end

@testset "Final states" begin

    a = Automaton(
        [Transition(State("1"), State("2"), :go), Transition(State("2"), State("3"), :done)],
        final = ["3"]
    )

    @test !StateMachines.isfinal(a)
    @test !StateMachines.isfinal(a, "1")
    @test !StateMachines.isfinal(a, "2")
    @test StateMachines.isfinal(a, "3")

    StateMachines.exec!(a, :go)
    @test !StateMachines.isfinal(a)

    StateMachines.exec!(a, :done)
    @test StateMachines.isfinal(a)

    # automaton with no final states: isfinal always false
    b = Automaton([Transition(State("1"), State("2"))])
    @test !StateMachines.isfinal(b)
    @test !StateMachines.isfinal(b, "1")
    @test !StateMachines.isfinal(b, "2")

end

@testset "No matching transition (sink)" begin

    a = Automaton([
        Transition(State("1"), State("2"), :go)
        Transition(State("2"), State("3"), :done)
    ])

    # unrecognized action stays in current state
    @test StateMachines.exec(a, :unknown) == "1"
    @test a.state == "1"

    # terminal state with no outgoing transitions stays put
    a.state = "3"
    @test StateMachines.exec(a, :go) == "3"
    @test a.state == "3"

    StateMachines.exec!(a, :go)
    @test a.state == "3"

end

@testset "Cycle detection" begin

    a = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("1"))
    ])

    @test_throws ErrorException StateMachines.exec(a)
    @test_throws ErrorException StateMachines.exec!(a)

    # cycle is only triggered in multistep mode; singlestep should be fine
    a.state = "1"
    StateMachines.singlestep!(a)
    @test StateMachines.exec!(a) == "2"
    @test StateMachines.exec!(a) == "1"

end

@testset "State Machine" begin

    a1 = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("3"))
    ])
    @test StateMachines.exec(a1) == "3"
    @test StateMachines.exec(a1, State("2")) == "3"

    a2 = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("3"))
        Transition(State("3"), State("4"), :update)
    ])
    @test StateMachines.exec(a2) == "3"
    @test StateMachines.exec(a2, :update) == "3"
    @test StateMachines.exec(a2, State("3"), :update) == "4"

    # exec with unknown state throws
    @test_throws AssertionError StateMachines.exec(a2, State("99"), :update)

    a3 = Automaton([
        Transition(State("1"), State("2"), :create)
        Transition(State("2"), State("3"))
        Transition(State("1"), State("4"), :update)
    ])
    @test StateMachines.exec(a3, :create) == "3"
    @test StateMachines.exec(a3, :update) == "4"

    a4 = Automaton([
        Transition(State("1"), State("2"), (a,_) -> a == :create)
        Transition(State("2"), State("3"))
        Transition(State("1"), State("4"), (a,_) -> a == :update)
    ])
    @test StateMachines.exec(a4, :create) == "3"
    @test StateMachines.exec(a4, :update) == "4"

    a4.state = "1"
    StateMachines.exec!(a4, :create)
    @test a4.state == "3"

    a4.state = "1"
    StateMachines.exec!(a4, :update)
    @test a4.state == "4"

    # exec! returns the new state
    a4.state = "1"
    @test StateMachines.exec!(a4, :create) == "3"

end

@testset "State Machine (with context)" begin

    a1 = Automaton([
        Transition(State("1"), State("2"), (a,c) -> a == :prepare && c == "valid")
        Transition(State("2"), State("3"), (a,c) -> a == :review && c == "prepared")
        Transition(State("1"), State("4"), (a,c) -> a == :delete && c != "reviewed")
    ])
    a1.state = "1"
    StateMachines.exec!(a1, :prepare, context = "invalid")
    @test a1.state == "1"

    a1.state = "1"
    StateMachines.exec!(a1, :prepare, context = "valid")
    @test a1.state == "2"

    a1.state = "2"
    StateMachines.exec!(a1, :review, context = "prepared")
    @test a1.state == "3"

    a1.state = "1"
    StateMachines.exec!(a1, :delete, context = "prepared")
    @test a1.state == "4"

    a1.state = "1"
    StateMachines.exec!(a1, :delete, context = "reviewed")
    @test a1.state == "1"

end

@testset "Transition execute callback" begin

    log = String[]

    a = Automaton([
        Transition(State("1"), State("2"), :go, ctx -> push!(log, ctx))
        Transition(State("2"), State("3"), :stop, nothing)
    ])

    # callback fires on matching transition and receives context
    a.state = "1"
    StateMachines.exec!(a, :go, context = "hello")
    @test a.state == "2"
    @test log == ["hello"]

    # callback does not fire on non-matching transition
    StateMachines.exec!(a, :stop, context = "world")
    @test a.state == "3"
    @test log == ["hello"]  # unchanged

    # callback fires again on a second match
    a2 = Automaton([
        Transition(State("1"), State("2"), :go, ctx -> push!(log, "second"))
        Transition(State("2"), State("3"))
    ])
    a2.state = "1"
    StateMachines.exec!(a2, :go)
    @test log == ["hello", "second"]

    # callback fires on unconditional transition too
    log2 = Int[]
    a3 = Automaton([
        Transition(State("1"), State("2"), nothing, ctx -> push!(log2, 1))
        Transition(State("2"), State("3"), :done)
    ])
    StateMachines.singlestep!(a3)
    StateMachines.exec!(a3)
    @test log2 == [1]

end

@testset "exec does not mutate automaton state" begin

    a = Automaton([
        Transition(State("1"), State("2"), :create)
        Transition(State("2"), State("3"))
    ])

    a.state = "1"
    result = StateMachines.exec(a, State("1"), :create)
    @test result == "3"
    @test a.state == "1"  # must not be mutated by exec

    # exec(a, action) form also non-mutating
    result2 = StateMachines.exec(a, :create)
    @test result2 == "3"
    @test a.state == "1"

end

@testset "State Machine Multi-step" begin

    a = Automaton([
        Transition(State("1"), State("2"))
        Transition(State("2"), State("3"))
        Transition(State("3"), State("4"), :update)
    ])

    a.state = "1"
    StateMachines.singlestep!(a)
    @test StateMachines.exec!(a) == "2"
    @test StateMachines.exec!(a) == "3"

    a.state = "1"
    StateMachines.multistep!(a)
    @test StateMachines.exec!(a) == "3"

    a.state = "1"
    StateMachines.multistep!(a)
    @test StateMachines.exec!(a, multistep = false) == "2"

    a.state = "1"
    StateMachines.singlestep!(a)
    @test StateMachines.exec!(a, multistep = true) == "3"

end

@testset "show methods" begin

    # Transition show: unconditional
    t1 = Transition(State("A"), State("B"))
    s1 = repr(t1)
    @test occursin("A", s1)
    @test occursin("B", s1)
    @test !occursin("input=", s1)
    @test !occursin("execute=", s1)

    # Transition show: symbol input
    t2 = Transition(State("A"), State("B"), :go)
    s2 = repr(t2)
    @test occursin(":go", s2)
    @test !occursin("execute=", s2)

    # Transition show: function input
    t3 = Transition(State("A"), State("B"), (a, _) -> true)
    @test occursin("Function", repr(t3))

    # Transition show: with execute callback
    t4 = Transition(State("A"), State("B"), :go, ctx -> nothing)
    @test occursin("execute=Function", repr(t4))

    # Automaton show: includes key fields
    a = Automaton(
        [State("1"), State("2"), State("3")],
        [Transition(State("1"), State("2"), :go), Transition(State("2"), State("3"))],
        State("1"),
        final = ["3"]
    )
    sa = repr(a)
    @test occursin("Automaton", sa)
    @test occursin("Start", sa)
    @test occursin("Final", sa)
    @test occursin("Transitions", sa)

    # Automaton show: no Final line when final is empty
    b = Automaton([Transition(State("1"), State("2"))])
    @test !occursin("Final", repr(b))

end

@testset "String-form Transition" begin

    # 2-arg
    t1 = Transition("from", "to")
    @test t1.from == State("from")
    @test t1.to   == State("to")
    @test t1.input   === nothing
    @test t1.execute === nothing

    # 3-arg: symbol input
    t2 = Transition("a", "b", :go)
    @test t2.from  == "a"
    @test t2.to    == "b"
    @test t2.input == :go
    @test t2.execute === nothing

    # 3-arg: function input
    t3 = Transition("a", "b", (act, _) -> act == :go)
    @test t3.input isa Function

    # 4-arg: with execute callback
    t4 = Transition("a", "b", :go, ctx -> nothing)
    @test t4.input == :go
    @test t4.execute isa Function

    # full Automaton built from string-literal transitions (README example 1)
    a = Automaton([
        Transition("s1", "s2", :create),
        Transition("s2", "s3"),
        Transition("s1", "s4", :update),
    ])
    @test a.states == ["s1", "s2", "s3", "s4"]
    @test a.start  == "s1"
    @test StateMachines.exec(a, :create) == "s3"
    @test StateMachines.exec(a, :update) == "s4"

end

@testset "String-form exec" begin

    a = Automaton([
        Transition(State("1"), State("2"), :go),
        Transition(State("2"), State("3")),
    ])

    # transition-system usage: caller supplies explicit current state as String
    @test StateMachines.exec(a, "1", :go) == "3"

    # no-action form
    a.state = "2"
    @test StateMachines.exec(a, "2") == "3"

    # unknown string state raises AssertionError
    @test_throws AssertionError StateMachines.exec(a, "99", :go)

    # multistep + string start state (README example 4 pattern)
    checkout = Automaton([
        Transition("new",        "processing", :submit),
        Transition("processing", "validated"),
        Transition("validated",  "complete"),
    ], final = ["complete"])
    @test StateMachines.exec(checkout, "new", :submit) == "complete"
    @test StateMachines.isfinal(checkout, "complete")

end

@testset "Complex workflows" begin

    workflow_log = String[]
    approval = Automaton(
        ["draft", "submitted", "approved", "rejected", "archived"],
        [
            Transition("draft", "submitted", :submit),
            Transition("submitted", "approved", (a,c) -> a == :review && get(c, :approved, false), ctx -> push!(workflow_log, "approved")),
            Transition("submitted", "rejected", (a,c) -> a == :review && !get(c, :approved, false), ctx -> push!(workflow_log, "rejected")),
            Transition("approved", "archived", :archive),
            Transition("rejected", "draft", :revise),
        ],
        "draft",
        final = ["archived"]
    )

    @test !StateMachines.isfinal(approval)
    StateMachines.exec!(approval, :submit)
    @test approval.state == "submitted"

    StateMachines.exec!(approval, :review, context = Dict(:approved => true))
    @test approval.state == "approved"
    @test workflow_log == ["approved"]

    StateMachines.exec!(approval, :archive)
    @test approval.state == "archived"
    @test StateMachines.isfinal(approval)

    approval.state = "submitted"
    workflow_log = String[]
    StateMachines.exec!(approval, :review, context = Dict(:approved => false))
    @test approval.state == "rejected"
    @test workflow_log == ["rejected"]

    StateMachines.exec!(approval, :revise)
    @test approval.state == "draft"

    recovery = Automaton([
        Transition("start", "validating", :begin),
        Transition("validating", "processing"),
        Transition("processing", "success", (a,c) -> a == :finish && c == :ok),
        Transition("processing", "error", (a,c) -> a == :finish && c == :fail),
        Transition("error", "processing", :retry),
        Transition("error", "failed", :abort),
    ], final = ["success", "failed"])

    recovery.state = "start"
    StateMachines.exec!(recovery, :begin)
    @test recovery.state == "processing"

    StateMachines.exec!(recovery, :finish, context = :fail)
    @test recovery.state == "error"

    StateMachines.exec!(recovery, :retry)
    @test recovery.state == "processing"

    StateMachines.exec!(recovery, :finish, context = :ok)
    @test recovery.state == "success"
    @test StateMachines.isfinal(recovery)

end

end