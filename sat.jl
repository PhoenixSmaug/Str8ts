"""
SAT based Str8ts Solver
* Encodes a Str8ts puzzle into a SAT problem, which is then solved with PicoSAT
* Idea behind encoding is that the check function of the simple solver would not be violated
* Allows verification that a solution is unique
"""

include("structs.jl")

using PicoSAT

# solve Str8ts puzzle with SAT and return if solvable
function solveSAT!(s::Str8ts)
    cnf, idToVar = encode(s)
    
    sol = PicoSAT.solve(cnf)

    if (sol == :unsatisfiable)
        return false, nothing
    end

    for i in sol
        if i > 0
            (x, y, n) = idToVar[i]
            s.numbers[x, y] = n
        end
    end

    return true, sol
end

# checks if a solution other than prevSol exists for the Str8ts puzzle
function existsAnotherSol(s::Str8ts, prevSol::Vector{Int})
    cnf, idToVar = encode(s)
    push!(cnf, [-1 * i for i in prevSol])
    sol = PicoSAT.solve(cnf)

    if (sol == :unsatisfiable)
        return false
    end
    
    return true
end


# encode Str8ts into a SAT problem
function encode(s::Str8ts)
    # initialize variable v[x, y, n] which is true iff tile (x, y) contains number n
    varToId = Dict{Tuple{Int, Int, Int}, Int}()
    idToVar = Dict{Int, Tuple{Int, Int, Int}}()

    t = 0
    for x in 1 : 9
        for y in 1 : 9
            for n in 1 : 9
                t += 1
                varToId[(x, y, n)] = t
                idToVar[t] = (x, y, n)
            end
        end
    end

    cnf = Vector{Vector{Int}}()

    # 1) If a tile contains a hint, v[x, y, n] must be true
    for x in 1 : 9
        for y in 1 : 9
            if s.numbers[x, y] != 0
                push!(cnf, [varToId[(x, y, s.numbers[x, y])]])
            end
        end
    end

    # 2) If a tile is empty and black, then it can't contain any value. Otherwise it contains exactly one value
    for x in 1 : 9
        for y in 1 : 9
            if s.isBlack[x, y] && s.numbers[x, y] == 0
                for n in 1 : 9
                    push!(cnf, [-1 * varToId[(x, y, n)]])
                end
                continue
            end

            # the tile contains at least one value
            push!(cnf, [varToId[(x, y, n)] for n in 1 : 9])

            # the title contains at most one value
            for n1 in 1 : 9
                for n2 in n1 + 1 : 9
                    push!(cnf, [-1 * varToId[(x, y, n1)], -1 * varToId[(x, y, n2)]])
                end
            end
        end
    end
    

    # 3) Each number appears at most per column/row
    for n in 1 : 9
        for x in 1 : 9
            for y1 in 1 : 9
                for y2 in y1 + 1 : 9
                    push!(cnf, [-1 * varToId[(x, y1, n)], -1 * varToId[(x, y2, n)]])
                end
            end
        end

        for y in 1 : 9
            for x1 in 1 : 9
                for x2 in x1 + 1 : 9
                    push!(cnf, [-1 * varToId[(x1, y, n)], -1 * varToId[(x2, y, n)]])
                end
            end
        end
    end

    # 4) Numbers in the same compartment can't differ by more than length(compartment) - 1
    for x in 1 : 9
        for y in 1 : 9
            if s.isBlack[x, y]
                continue
            end

            # first tile of horizontal compartment
            if y == 1 || s.isBlack[x, y - 1]
                (i, j) = (x, y)
                comp = Vector{Tuple{Int, Int}}()

                while true
                    push!(comp, (i, j))
                    j += 1

                    if j > 9 || s.isBlack[i, j]
                        break
                    end
                end

                encodeCompart(cnf, varToId, comp)
            end

            # first tile of vertical compartment
            if x == 1 || s.isBlack[x - 1, y]
                (i, j) = (x, y)
                comp = Vector{Tuple{Int, Int}}()

                while true
                    push!(comp, (i, j))
                    i += 1

                    if i > 9 || s.isBlack[i, j]
                        break
                    end
                end

                encodeCompart(cnf, varToId, comp)
            end
        end
    end

    return cnf, idToVar
end

@inline function encodeCompart(cnf::Vector{Vector{Int}}, varToId::Dict{Tuple{Int, Int, Int}, Int}, comp::Vector{Tuple{Int, Int}})
    m = length(comp)

    if 2 <= m <= 8  # compartments of length 1 and 9 don't allow constraints
        for t1 in comp
            for t2 in comp
                if t1 != t2
                    for n1 in 1 : 9
                        for n2 in n1 + m : 9
                            push!(cnf, [-1 * varToId[(t1[1], t1[2], n1)], -1 * varToId[(t2[1], t2[2], n2)]])
                        end

                        for n2 in 1 : n1 - m
                            push!(cnf, [-1 * varToId[(t1[1], t1[2], n1)], -1 * varToId[(t2[1], t2[2], n2)]])
                        end
                    end
                end
            end
        end
    end
end

# (c) Mia Muessig