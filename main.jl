include("structs.jl")
include("backtrack.jl")
include("sat.jl")
include("human.jl")

const DIABOLIC_WIKIPEDIA_PUZZLE = "##2..#9..
                            #....h6.#
                            52..f...#
                            .........
                            .#a5..##.
                            ........6
                            #...e..3.
                            h..i....#
                            ...#.2.d#"

function trySimpleSolver()
    println("Diabolic Str8ts featured on Wikipedia")
    # https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png
    warmup = SimpleStr8ts(DIABOLIC_WIKIPEDIA_PUZZLE)
    solveSimple!(warmup)

    s = SimpleStr8ts(DIABOLIC_WIKIPEDIA_PUZZLE)

    print(s)
    @time solveSimple!(s)
    println(s)
end

function trySATSolver()
    println("Diabolic Str8ts featured on Wikipedia")
    # https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png
    warmup = SimpleStr8ts(DIABOLIC_WIKIPEDIA_PUZZLE)
    solveSAT!(warmup)

    s = SimpleStr8ts(DIABOLIC_WIKIPEDIA_PUZZLE)

    print(s)
    @time solveSAT!(s)
    println(s)
end

function tryHumanSolver()
    println("Diabolic Str8ts featured on Wikipedia")
    # https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png
    warmup = Str8ts(DIABOLIC_WIKIPEDIA_PUZZLE)
    solveHuman!(warmup, verbose=false)  # purpose is to exclude compilation time from time measurement

    s = Str8ts(DIABOLIC_WIKIPEDIA_PUZZLE)

    print(s)
    moves = @time solveHuman!(s, verbose=false)
    println(s)
    println("Hardest move hardness: $(puzzleHardness(moves))")
end

println("Using Backtracking Solver:")
println("")
trySimpleSolver()
println("")
println("Using SAT Solver:")
println("")
trySATSolver()
println("")
println("Using Human Solver:")
println("")
tryHumanSolver()
println("")

# (c) Mia Muessig