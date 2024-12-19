using StateMachines
using Test

@testset "Object instantiation" begin

    @test State("test") == "test"

    @test Transition(State("from"), State("to")).from == "from"
    @test Transition(State("from"), State("to")).to == "to"
    @test Transition(State("from"), State("to")).input === nothing
    @test Transition(State("from"), State("to"), :write).input == :write

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

    @test_throws AssertionError Automaton([])

    @test_throws AssertionError Automaton(
        [State("1"), State("2"), State("3")],
        [
            Transition(State("1"), State("2"))
            Transition(State("2"), State("4"))
        ],
        State("2")
    )

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

end

@testset "State Machine (inner state)" begin

    a1 = Automaton([
        Transition(State("1"), State("2"), (a,_) -> a == :create)
        Transition(State("2"), State("3"))
        Transition(State("1"), State("4"), (a,_) -> a == :update)
    ])
    a1.state = "1"
    StateMachines.exec!(a1, :create)
    @test a1.state == "3"

    a1.state = "1"
    StateMachines.exec!(a1, :update)
    @test a1.state == "4"

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