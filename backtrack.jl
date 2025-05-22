"""
Backtracking Str8ts Solver
* Simple logic in around 70 non-empty lines
* Still solves even extreme Str8ts puzzles in milliseconds
"""

include("structs.jl")

# solve Str8ts puzzle with backtracking and return if solvable
function solveSimple!(s::Str8ts)
    x, y = findEmpty(s)
    
    if (x == 0 && y == 0)  # Str8ts filled
        return true
    end

    for i in 1 : 9
        if (check(s, x, y, i))
            s.numbers[x, y] = i

            if (solveSimple!(s))
                return true
            end

            s.numbers[x, y] = 0
        end
    end

    return false
end

# find first empty field in s
@inline function findEmpty(s::Str8ts)
    for i in 1 : 9
        for j in 1 : 9
            if (s.numbers[i, j] == 0 && !s.isBlack[i, j])
                return i, j
            end
        end
    end

    return 0, 0
end

# check if adding value on position (x, y) violates constraints
@inline function check(s::Str8ts, x::Int, y::Int, value::Int)
    for i in 1 : 9  # check row
        if (i != y && s.numbers[x, i] == value)
            return false
        end
    end

    for i in 1 : 9  # check column
        if (i != x && s.numbers[i, y] == value)
            return false
        end
    end

    # Check vertical and horizontal compartments
    if !checkCompart(s, x, y, value, [(1, 0), (-1, 0)]) ||  !checkCompart(s, x, y, value, [(0, 1), (0, -1)])
        return false
    end

    return true
end

# check if compartment already contains a value so large or small that a consecutive sequence would be impossible
@inline function checkCompart(s::Str8ts, x::Int, y::Int, value::Int, directions::Vector{Tuple{Int64, Int64}})
    numCompartment = 1  # size of the compartment containing (x, y)
    maxDiff = 0  # maximum difference of a number in the compartment to value

    for d in directions
        (i, j) = (x, y)

        while true
            (i, j) = (i, j) .+ d

            if !(1 <= i <= 9) || !(1 <= j <= 9) || s.isBlack[i, j]
                break
            end

            numCompartment += 1
            if s.numbers[i, j] != 0
                maxDiff = max(maxDiff, abs(s.numbers[i, j] - value))
            end
        end
    end

    return maxDiff <= numCompartment - 1
end

# (c) Mia Muessig