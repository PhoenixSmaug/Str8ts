"""
    Str8ts

Simple datastructure used for backtracking and SAT solving.

# Arguments
- `numbers`: Holds value of the tile or 0 if tile is empty
- `isBlack`: If tile is black or not
"""
struct Str8ts
    numbers::Array{Int, 2}
    isBlack::Array{Bool, 2}
end


"""
Construct a Str8ts from the string representation.
"""
function Str8ts(board::String)
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

    return Str8ts(numbers, isBlack)
end


"""
Pretty print Str8ts
"""
function Base.show(io::IO, s::Str8ts)
    BLACK_BG = "\e[40m"     # Black background
    WHITE_BG = "\e[47m"     # White background
    RESET = "\e[0m"         # Reset formatting
    WHITE_FG = "\e[37m"     # White foreground for black tiles
    BLACK_FG = "\e[30m"     # Black foreground for white tiles
    
    for row in 1:9
        for col in 1:9
            bg = s.isBlack[row, col] ? BLACK_BG : WHITE_BG
            num = s.numbers[row, col]

            if num == 0
                print(io, bg * "   " * RESET)  # Empty square
            else
                # White text on black tiles, black text on white tiles
                fg = s.isBlack[row, col] ? WHITE_FG : BLACK_FG
                print(io, bg * fg * " " * string(num) * " " * RESET)
            end
        end
        println(io)
    end
end

# (c) Mia Muessig