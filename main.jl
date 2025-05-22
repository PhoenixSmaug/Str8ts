include("backtrack.jl")
include("sat.jl")

function trySimpleSolver()
    println("Diabolic Str8ts featured on Wikipedia")
    # https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png
    s = Str8ts("##2..#9..
                    #....h6.#
                    52..f...#
                    .........
                    .#a5..##.
                    ........6
                    #...e..3.
                    h..i....#
                    ...#.2.d#")

    print(s)
    @time solveSimple!(s)
    println(s)
end

function trySATSolver()
    println("Diabolic Str8ts featured on Wikipedia")
    # https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png
    s = Str8ts("##2..#9..
                    #....h6.#
                    52..f...#
                    .........
                    .#a5..##.
                    ........6
                    #...e..3.
                    h..i....#
                    ...#.2.d#")

    print(s)
    @time solveSAT!(s)
    println(s)
end

println("Using Backtracking Solver:")
println("")
trySimpleSolver()
println("")
println("Using SAT Solver:")
println("")
trySATSolver()
println("")

# (c) Mia Muessig