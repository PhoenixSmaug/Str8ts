const Compartment = Vector{Tuple{Int, Int}}


"""
    SimpleStr8ts

Lightweight datastructure used by backtracking and SAT solving.

# Fields
- `numbers`: numbers[r, c] is the number at (r, c), or 0 if empty
- `isBlack`: isBlack[r, c] is true iff the tile at (r, c) is a black cell
"""
mutable struct SimpleStr8ts
    numbers::Array{Int, 2}
    isBlack::Array{Bool, 2}
end


"""
    Str8ts

Richer datastructure used by the human-like solver.
"""
mutable struct Str8ts
    solved::Array{Bool, 2}
    numbers::Array{Int, 2}
    isBlack::Array{Bool, 2}
    candidates::Array{BitSet, 2}
    rowCompartments::Vector{Compartment}
    colCompartments::Vector{Compartment}
    cellToRowCompartment::Array{Int, 2}
    cellToColCompartment::Array{Int, 2}
    occRow::Array{Set{Tuple{Int,Int}}, 2}
    occCol::Array{Set{Tuple{Int,Int}}, 2}
end


"""
Construct a SimpleStr8ts from the string representation.
"""
function SimpleStr8ts(board::AbstractString)
    board = replace(board, r"\s+" => "")
    
    if length(board) != 81
        throw(ArgumentError("Board string must be exactly 81 characters long"))
    end
    
    numbers = zeros(Int, 9, 9)
    isBlack = falses(9, 9)
    for (idx, char) in enumerate(board)
        # convert 1D index to 2D indices
        row = div(idx - 1, 9) + 1
        col = mod(idx - 1, 9) + 1
        
        if char == '#'
            isBlack[row, col] = true
        elseif char == '.'
            continue
        elseif islowercase(char)
            isBlack[row, col] = true
            numbers[row, col] = Int(char - 'a' + 1)
        elseif isdigit(char)
            numbers[row, col] = parse(Int, char)
        else
            throw(ArgumentError("Invalid character: $char"))
        end
    end

    return SimpleStr8ts(numbers, isBlack)
end


"""
Construct a Str8ts from the string representation.
"""
function Str8ts(board::AbstractString)
    board = replace(board, r"\s+" => "")

    if length(board) != 81
        throw(ArgumentError("Board string must be exactly 81 characters long"))
    end

    numbers = zeros(Int, 9, 9)
    isBlack = falses(9, 9)
    solved = falses(9, 9)
    candidates = [BitSet() for _ in 1:9, _ in 1:9]

    for (idx, char) in enumerate(board)
        row = div(idx - 1, 9) + 1
        col = mod(idx - 1, 9) + 1

        if char == '#'
            isBlack[row, col] = true
        elseif char == '.'
            continue
        elseif islowercase(char)
            isBlack[row, col] = true
            numbers[row, col] = Int(char - 'a' + 1)
        elseif isdigit(char)
            numbers[row, col] = parse(Int, char)
            solved[row, col] = true
        else
            throw(ArgumentError("Invalid character: $char"))
        end
    end

    rowCompartments = Compartment[]
    colCompartments = Compartment[]
    cellToRowCompartment = zeros(Int, 9, 9)
    cellToColCompartment = zeros(Int, 9, 9)

    for r in 1:9
        c = 1
        while c <= 9
            if !isBlack[r, c]
                comp = Compartment()
                while c <= 9 && !isBlack[r, c]
                    push!(comp, (r, c))
                    c += 1
                end
                if length(comp) > 0
                    push!(rowCompartments, comp)
                    idx = length(rowCompartments)
                    for (rr, cc) in comp
                        cellToRowCompartment[rr, cc] = idx
                    end
                end
            else
                c += 1
            end
        end
    end

    for c in 1:9
        r = 1
        while r <= 9
            if !isBlack[r, c]
                comp = Compartment()
                while r <= 9 && !isBlack[r, c]
                    push!(comp, (r, c))
                    r += 1
                end
                if length(comp) > 0
                    push!(colCompartments, comp)
                    idx = length(colCompartments)
                    for (rr, cc) in comp
                        cellToColCompartment[rr, cc] = idx
                    end
                end
            else
                r += 1
            end
        end
    end

    occRow = [Set{Tuple{Int,Int}}() for _ in 1:9, _ in 1:9]
    occCol = [Set{Tuple{Int,Int}}() for _ in 1:9, _ in 1:9]

    s = Str8ts(solved, numbers, isBlack, candidates, rowCompartments, colCompartments,
               cellToRowCompartment, cellToColCompartment, occRow, occCol)

    for r in 1:9
        for c in 1:9
            if !isBlack[r, c]
                if solved[r, c]
                    s.candidates[r, c] = BitSet(numbers[r, c])
                else
                    s.candidates[r, c] = BitSet(1:9)
                end
            end
        end
    end

    for r in 1:9
        for c in 1:9
            if isBlack[r, c] && numbers[r, c] != 0
                num = numbers[r, c]
                for cc in 1:9
                    if !isBlack[r, cc]
                        delete!(s.candidates[r, cc], num)
                    end
                end
                for rr in 1:9
                    if !isBlack[rr, c]
                        delete!(s.candidates[rr, c], num)
                    end
                end
            end
        end
    end

    for r in 1:9
        for c in 1:9
            if solved[r, c]
                num = numbers[r, c]
                for cc in 1:9
                    if cc != c && !isBlack[r, cc]
                        delete!(s.candidates[r, cc], num)
                    end
                end
                for rr in 1:9
                    if rr != r && !isBlack[rr, c]
                        delete!(s.candidates[rr, c], num)
                    end
                end
            end
        end
    end

    for r in 1:9
        for c in 1:9
            if !isBlack[r, c]
                for n in s.candidates[r, c]
                    push!(s.occRow[r, n], (r, c))
                    push!(s.occCol[c, n], (r, c))
                end
            end
        end
    end

    return s
end


function showBoard(io::IO, numbers::Array{Int,2}, isBlack::Array{Bool,2})
    BLACK_BG = "\e[40m"     # Black background
    WHITE_BG = "\e[47m"     # White background
    RESET = "\e[0m"         # Reset formatting
    WHITE_FG = "\e[37m"     # White foreground for black tiles
    BLACK_FG = "\e[30m"     # Black foreground for white tiles
    
    for row in 1:9
        for col in 1:9
            bg = isBlack[row, col] ? BLACK_BG : WHITE_BG
            num = numbers[row, col]

            if num == 0
                print(io, bg * "   " * RESET)  # Empty square
            else
                # White text on black tiles, black text on white tiles
                fg = isBlack[row, col] ? WHITE_FG : BLACK_FG
                print(io, bg * fg * " " * string(num) * " " * RESET)
            end
        end
        println(io)
    end
end


"""
Pretty print SimpleStr8ts
"""
function Base.show(io::IO, s::SimpleStr8ts)
    showBoard(io, s.numbers, s.isBlack)
end


"""
Pretty print Str8ts
"""
function Base.show(io::IO, s::Str8ts)
    showBoard(io, s.numbers, s.isBlack)
end

# (c) Mia Muessig