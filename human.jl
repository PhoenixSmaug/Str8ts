"""
Human-like Str8ts Solver

Solves Str8ts puzzles using human reasoning strategies, without guessing.
Based on the strategies described in str8ts-strategies.txt.

(c) Mia Muessig
"""

using Combinatorics
using MatrixNetworks
using SparseArrays
@isdefined(Str8ts) || include("structs.jl")

# ============================================================================
# HARDNESS SCALE (0-100)
# All strategy functions return 0 (no progress) or a hardness value > 0.
# Strategies with size-dependent complexity return higher values for larger sizes.
# ============================================================================

const H_SINGLE           = 3    # Naked / hidden single
const H_SURE_CANDIDATES  = 5   # Sure candidates cross-compartment elimination

stranded_hardness(k::Int)    = 10 + (k - 1) * 2   # stranded digits
split_hardness(k::Int)       = 15 + (k - 1) * 2   # split compartments (k≥3)
mindgap_hardness(k::Int)     = 15 + (k - 1) * 2   # mind the gap
range_check_hardness(k::Int) = 20 + (k - 1) * 3   # bipartite range check

# Naked sets: setSize 2→35, 3→40, 4→45, 5→50
naked_set_hardness(size::Int)    = 20 + (size - 1) * 5
# Hidden sets: setSize 2→37, 3→42, 4→47, 5→52
hidden_set_hardness(size::Int)   = 25 + (size - 1) * 5

const H_LOCKED           = 30   # Locked compartments
# Sea creatures: n=2→60 (X-Wing), 3→65, 4→70, 5→75
sea_creature_hardness(n::Int)    = 50 + n * 5
const H_UNIQUE           = 60   # Unique solution constraint
const H_SETTI            = 70   # Setti's rule
const H_SETTI_CONSIDER   = 75   # Setti considerations
const H_SETTI_SET        = 75   # Combined Settis
const H_YWING            = 80   # Y-Wing
const H_BINARY_GUESS     = 90   # Binary contradiction guess (single level)
const H_UNSOLVABLE       = 100  # Could not solve with available strategies

"""
Show candidates for a specific cell
"""
function showCandidates(s::Str8ts, r::Int, c::Int)
    println("Candidates at ($r, $c): ", collect(s.candidates[r, c]))
end


"""
    add!(s, r, c, num)

Set the tile at position (r, c) to num and update candidates.
"""
function add!(s::Str8ts, r::Int, c::Int, num::Int)
    if s.solved[r, c]
        return
    end
    
    s.solved[r, c] = true
    s.numbers[r, c] = num
    s.candidates[r, c] = BitSet(num)
    
    propagateAdd!(s, r, c, num)
end


"""
    propagateAdd!(s, r, c, num)

Propagate constraints after adding num at (r, c).
"""
function propagateAdd!(s::Str8ts, r::Int, c::Int, num::Int)
    # Remove num from all other cells in row
    for cc in 1:9
        if cc != c && !s.isBlack[r, cc]
            remCandidate!(s, r, cc, num)
        end
    end
    
    # Remove num from all other cells in column
    for rr in 1:9
        if rr != r && !s.isBlack[rr, c]
            remCandidate!(s, rr, c, num)
        end
    end
    
    # Remove all other candidates from (r, c)'s occurrence sets
    for n in 1:9
        if n != num
            delete!(s.occRow[r, n], (r, c))
            delete!(s.occCol[c, n], (r, c))
        end
    end
end


"""
    remCandidate!(s, r, c, num)

Remove num as a candidate from cell (r, c).
"""
function remCandidate!(s::Str8ts, r::Int, c::Int, num::Int)
    if num in s.candidates[r, c]
        delete!(s.candidates[r, c], num)
        delete!(s.occRow[r, num], (r, c))
        delete!(s.occCol[c, num], (r, c))
    end
end


"""
    getCompartmentCandidates(s, comp)

Get all candidates that appear in any cell of the compartment.
"""
function getCompartmentCandidates(s::Str8ts, comp::Compartment)
    cands = BitSet()
    for (r, c) in comp
        union!(cands, s.candidates[r, c])
    end
    return cands
end


"""
    getCompartmentSolvedValues(s, comp)

Get all values that are already solved/placed in the compartment.
"""
function getCompartmentSolvedValues(s::Str8ts, comp::Compartment)
    solved = BitSet()
    for (r, c) in comp
        if s.solved[r, c]
            push!(solved, s.numbers[r, c])
        end
    end
    return solved
end


"""
    getCompartmentRanges(s, comp)

Get all possible ranges for a compartment, accounting for both candidates and solved values.
"""
function getCompartmentRanges(s::Str8ts, comp::Compartment)
    cands = getCompartmentCandidates(s, comp)
    solved = getCompartmentSolvedValues(s, comp)
    return getPossibleRanges(cands, length(comp), required=solved)
end


"""
    getPossibleRanges(candidates, size; required=BitSet())

Get all possible ranges (consecutive sequences) of given size that can be formed
from the candidates. If `required` is provided, ranges must contain all required values.
The `required` parameter should contain values that are already placed in the compartment.
"""
function getPossibleRanges(candidates::BitSet, size::Int; required::BitSet=BitSet())
    ranges = Vector{UnitRange{Int}}()
    if size == 0
        return ranges
    end
    
    for start in 1:(10-size)
        rng = start:(start+size-1)
        # Check if range is possible (all numbers exist in candidates)
        if all(n in candidates for n in rng)
            # Also check that all required values are within the range
            if all(n in rng for n in required)
                push!(ranges, rng)
            end
        end
    end
    return ranges
end


"""
    getSureCandidates(ranges, size)

Get sure candidates: numbers that appear in ALL possible ranges.
"""
function getSureCandidates(ranges::Vector{UnitRange{Int}}, size::Int)
    if isempty(ranges)
        return BitSet()
    end
    
    # Intersection of all ranges
    sure = BitSet(first(ranges))
    for rng in ranges[2:end]
        intersect!(sure, BitSet(rng))
    end
    return sure
end


"""
    isValid(s)

Check if the Str8ts is still solvable (no cell has empty candidates).
"""
function isValid(s::Str8ts)
    for r in 1:9
        for c in 1:9
            if !s.isBlack[r, c] && isempty(s.candidates[r, c])
                return false
            end
        end
    end
    return true
end


"""
    isDone(s)

Check if the Str8ts is completely solved.
"""
function isDone(s::Str8ts)
    for r in 1:9
        for c in 1:9
            if !s.isBlack[r, c] && !s.solved[r, c]
                return false
            end
        end
    end
    return true
end


# ============================================================================
# STRATEGIES
# ============================================================================

"""
    useSingle(s)

Find and apply naked or hidden singles.
- Naked single: cell has only one candidate
- Hidden single: a sure candidate appears in only one cell of a compartment
"""
function useSingle(s::Str8ts)
    # Naked singles
    for r in 1:9
        for c in 1:9
            if !s.isBlack[r, c] && !s.solved[r, c] && length(s.candidates[r, c]) == 1
                add!(s, r, c, first(s.candidates[r, c]))
                return H_SINGLE
            end
        end
    end

    # Hidden singles in row compartments
    for comp in s.rowCompartments
        ranges = getCompartmentRanges(s, comp)
        sure = getSureCandidates(ranges, length(comp))

        for n in sure
            cells_with_n = [(r, c) for (r, c) in comp if n in s.candidates[r, c]]
            if length(cells_with_n) == 1
                (r, c) = cells_with_n[1]
                if !s.solved[r, c]
                    add!(s, r, c, n)
                    return H_SINGLE
                end
            end
        end
    end

    # Hidden singles in column compartments
    for comp in s.colCompartments
        ranges = getCompartmentRanges(s, comp)
        sure = getSureCandidates(ranges, length(comp))

        for n in sure
            cells_with_n = [(r, c) for (r, c) in comp if n in s.candidates[r, c]]
            if length(cells_with_n) == 1
                (r, c) = cells_with_n[1]
                if !s.solved[r, c]
                    add!(s, r, c, n)
                    return H_SINGLE
                end
            end
        end
    end

    return 0
end


"""
    hasPerfectMatching(cellCandidates, rangeValues)

Check if there exists a perfect matching between cells and values.
cellCandidates: Vector of BitSets representing candidate values for each cell
rangeValues: Vector of values that must be assigned
Returns true if a perfect matching exists.
"""
function hasPerfectMatching(cellCandidates::Vector{BitSet}, rangeValues::Vector{Int})
    n = length(cellCandidates)
    if n != length(rangeValues)
        return false
    end
    
    if n == 0
        return true
    end
    
    # Build bipartite graph adjacency matrix
    # Rows: cells, Cols: values
    # A[i,j] = 1 if cell i can have value rangeValues[j]
    rows = Int[]
    cols = Int[]
    for i in 1:n
        for j in 1:n
            if rangeValues[j] in cellCandidates[i]
                push!(rows, i)
                push!(cols, j)
            end
        end
    end
    
    if isempty(rows)
        return false
    end
    
    vals = ones(Int, length(rows))
    A = sparse(rows, cols, vals, n, n)
    
    # Find maximum matching
    result = bipartite_matching(A)
    
    # Check if it's a perfect matching
    return result.cardinality == n
end

"""
    useCompartmentRangeCheck(s, compSize)

Remove candidates that cannot be part of any valid assignment using bipartite matching.
Only processes compartments of exactly `compSize` cells.
Returns `range_check_hardness(compSize)` if progress was made, else 0.
"""
function useCompartmentRangeCheck(s::Str8ts, compSize::Int)
    effective = false

    for comp in vcat(s.rowCompartments, s.colCompartments)
        size = length(comp)
        if size != compSize
            continue
        end
        
        ranges = getCompartmentRanges(s, comp)
        
        if isempty(ranges)
            continue
        end
        
        # Get unsolved cells
        unsolved = [(r, c) for (r, c) in comp if !s.solved[r, c]]
        n_unsolved = length(unsolved)
        
        if n_unsolved == 0
            continue
        end
        
        # For each unsolved cell, collect valid values across all ranges
        validAssignments = [BitSet() for _ in 1:n_unsolved]
        
        for rng in ranges
            rangeValues = collect(rng)
            
            # Check if solved cells are compatible with this range
            compatibleWithSolved = true
            solvedValues = Int[]
            for (r, c) in comp
                if s.solved[r, c]
                    if !(s.numbers[r, c] in rng)
                        compatibleWithSolved = false
                        break
                    end
                    push!(solvedValues, s.numbers[r, c])
                end
            end
            
            if !compatibleWithSolved
                continue
            end
            
            # Remove solved values from available values
            availableValues = setdiff(rangeValues, solvedValues)
            
            if length(availableValues) != n_unsolved
                continue
            end
            
            # Get current candidates for unsolved cells
            cellCandidates = [s.candidates[r, c] for (r, c) in unsolved]
            
            # First check if this range allows any perfect matching at all
            if !hasPerfectMatching(cellCandidates, collect(availableValues))
                continue
            end
            
            # For each cell, test which values can be part of a valid matching
            for i in 1:n_unsolved
                for val in availableValues
                    if !(val in cellCandidates[i])
                        continue
                    end
                    
                    # Test if assigning val to cell i allows a perfect matching
                    # Create restricted candidates where cell i can only have val
                    testCandidates = [i == j ? BitSet([val]) : cellCandidates[j] for j in 1:n_unsolved]
                    
                    if hasPerfectMatching(testCandidates, collect(availableValues))
                        push!(validAssignments[i], val)
                    end
                end
            end
        end
        
        # Remove candidates that are not in validAssignments
        for i in 1:n_unsolved
            (r, c) = unsolved[i]
            for n in collect(s.candidates[r, c])
                if !(n in validAssignments[i])
                    remCandidate!(s, r, c, n)
                    effective = true
                end
            end
        end
    end

    return effective ? range_check_hardness(compSize) : 0
end


"""
    useStrandedDigits(s, compSize)

Remove stranded digits - candidates that cannot be part of any valid sequence.
Only processes compartments of exactly `compSize` cells.
Returns `stranded_hardness(compSize)` if progress was made, else 0.
"""
function useStrandedDigits(s::Str8ts, compSize::Int)
    effective = false

    for comp in vcat(s.rowCompartments, s.colCompartments)
        size = length(comp)
        if size != compSize
            continue
        end
        
        cands = getCompartmentCandidates(s, comp)
        solved = getCompartmentSolvedValues(s, comp)
        
        # For each candidate, check if it can be part of a valid range
        for n in collect(cands)
            # Find all ranges containing n
            canBePartOfRange = false
            for start in max(1, n - size + 1):min(n, 10 - size)
                rng = start:(start + size - 1)
                # Check if range is possible: all range numbers are candidates AND
                # all solved values are within the range
                if all(m in cands for m in rng) && all(m in rng for m in solved)
                    canBePartOfRange = true
                    break
                end
            end
            
            if !canBePartOfRange
                # Remove n from all cells in compartment
                for (r, c) in comp
                    if n in s.candidates[r, c]
                        remCandidate!(s, r, c, n)
                        effective = true
                    end
                end
            end
        end
        
        # Special case: bridging digits for size-2 compartments
        # If a cell has candidate n, and the only adjacent candidate (n-1 or n+1)
        # is also only in this cell, then n is stranded for this cell
        if size == 2
            cands = getCompartmentCandidates(s, comp)  # Refresh
            for i in 1:2
                (r, c) = comp[i]
                (r2, c2) = comp[3 - i]  # The other cell

                if s.solved[r, c]
                    continue
                end

                otherCands = s.candidates[r2, c2]

                for n in collect(s.candidates[r, c])
                    # For n to be valid, either n-1 or n+1 must be in the other cell
                    hasAdjacent = (n - 1) in otherCands || (n + 1) in otherCands
                    if !hasAdjacent
                        remCandidate!(s, r, c, n)
                        effective = true
                    end
                end
            end
        end
    end

    return effective ? stranded_hardness(compSize) : 0
end


"""
    useSplitCompartment(s, compSize)

Handle split compartments - when possible ranges don't overlap.
Only processes compartments of exactly `compSize` cells (compSize ≥ 3).
Returns `split_hardness(compSize)` if progress was made, else 0.
"""
function useSplitCompartment(s::Str8ts, compSize::Int)
    effective = false

    for comp in vcat(s.rowCompartments, s.colCompartments)
        size = length(comp)
        if size != compSize
            continue
        end
        
        ranges = getCompartmentRanges(s, comp)
        
        if length(ranges) <= 1
            continue
        end
        
        # Group ranges by overlap
        groups = Vector{Vector{UnitRange{Int}}}()
        for rng in ranges
            found = false
            for group in groups
                if any(overlaps(rng, r) for r in group)
                    push!(group, rng)
                    found = true
                    break
                end
            end
            if !found
                push!(groups, [rng])
            end
        end
        
        # Merge overlapping groups
        merged = true
        while merged
            merged = false
            for i in 1:length(groups)
                for j in i+1:length(groups)
                    if any(overlaps(r1, r2) for r1 in groups[i] for r2 in groups[j])
                        append!(groups[i], groups[j])
                        deleteat!(groups, j)
                        merged = true
                        break
                    end
                end
                if merged
                    break
                end
            end
        end
        
        if length(groups) > 1
            # We have a split compartment!
            # For each group, analyze independently
            for group in groups
                groupSure = getSureCandidates(group, size)

                # Sure candidates in this group must appear only in cells that could be in this range
                groupMin = minimum(first(r) for r in group)
                groupMax = maximum(last(r) for r in group)
                groupCands = BitSet(groupMin:groupMax)

                for n in groupSure
                    # n is sure in this group - remove from cells that can't be part of this group
                    for (r, c) in comp
                        if !s.solved[r, c] && n in s.candidates[r, c]
                            # Check if this cell could be in this group's range
                            cellCands = intersect(s.candidates[r, c], groupCands)
                            if isempty(cellCands)
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
            end
        end
    end

    return effective ? split_hardness(compSize) : 0
end

@inline function overlaps(r1::UnitRange{Int}, r2::UnitRange{Int})
    return first(r1) <= last(r2) && first(r2) <= last(r1)
end


"""
    useMindTheGap(s, compSize)

If a cell has a large gap (distance >= compartment size) between its candidates,
those extreme candidates cannot appear in other cells.
Only processes compartments of exactly `compSize` cells.
Returns `mindgap_hardness(compSize)` if progress was made, else 0.
"""
function useMindTheGap(s::Str8ts, compSize::Int)
    effective = false

    for comp in vcat(s.rowCompartments, s.colCompartments)
        size = length(comp)
        if size != compSize
            continue
        end
        
        for (r, c) in comp
            if s.solved[r, c]
                continue
            end
            
            cands = collect(s.candidates[r, c])
            if length(cands) < 2
                continue
            end
            
            sort!(cands)
            minCand = first(cands)
            maxCand = last(cands)
            
            gap = maxCand - minCand
            if gap >= size
                # Large-gap eliminations (conservative):
                # 1) If exactly two candidates (min,max), remove both from other cells.
                # 2) If exactly three candidates and only one side is singleton,
                #    remove only that singleton side candidate from other cells.
                lowSideCands = filter(n -> n <= minCand + (gap - size), cands)
                highSideCands = filter(n -> n >= maxCand - (gap - size), cands)

                if length(cands) == 2 && length(lowSideCands) == 1 && length(highSideCands) == 1
                    lowForced = lowSideCands[1]
                    highForced = highSideCands[1]
                    for (r2, c2) in comp
                        if (r2, c2) != (r, c) && !s.solved[r2, c2]
                            if lowForced in s.candidates[r2, c2]
                                remCandidate!(s, r2, c2, lowForced)
                                effective = true
                            end
                            if highForced in s.candidates[r2, c2]
                                remCandidate!(s, r2, c2, highForced)
                                effective = true
                            end
                        end
                    end
                elseif length(cands) == 3
                    if length(lowSideCands) == 1 && length(highSideCands) > 1 && lowSideCands[1] == minCand
                        lowForced = lowSideCands[1]
                        for (r2, c2) in comp
                            if (r2, c2) != (r, c) && !s.solved[r2, c2] && lowForced in s.candidates[r2, c2]
                                remCandidate!(s, r2, c2, lowForced)
                                effective = true
                            end
                        end
                    elseif length(highSideCands) == 1 && length(lowSideCands) > 1 && highSideCands[1] == maxCand
                        highForced = highSideCands[1]
                        for (r2, c2) in comp
                            if (r2, c2) != (r, c) && !s.solved[r2, c2] && highForced in s.candidates[r2, c2]
                                remCandidate!(s, r2, c2, highForced)
                                effective = true
                            end
                        end
                    end
                end
            end
        end
        
        # Check for gaps spanning two cells - but only when both cells have exactly 2 candidates
        # with a shared bridge
        for i in 1:length(comp)
            for j in i+1:length(comp)
                (r1, c1) = comp[i]
                (r2, c2) = comp[j]
                
                if s.solved[r1, c1] || s.solved[r2, c2]
                    continue
                end
                
                cands1 = s.candidates[r1, c1]
                cands2 = s.candidates[r2, c2]
                
                # Only apply when both cells have exactly 2 candidates
                if length(cands1) != 2 || length(cands2) != 2
                    continue
                end
                
                # Find common candidate (bridge)
                common = intersect(cands1, cands2)
                if length(common) != 1
                    continue
                end
                
                bridge = first(common)
                low = first(setdiff(cands1, common))
                high = first(setdiff(cands2, common))
                
                # Make sure low < bridge < high
                if low > bridge
                    low, high = high, low
                    r1, c1, r2, c2 = r2, c2, r1, c1
                end
                
                if !(low < bridge < high)
                    continue
                end
                
                gap = high - low
                if gap >= size
                    # Remove bridge from other cells
                    for (r, c) in comp
                        if (r, c) != (r1, c1) && (r, c) != (r2, c2) && !s.solved[r, c]
                            if bridge in s.candidates[r, c]
                                remCandidate!(s, r, c, bridge)
                                effective = true
                            end
                        end
                    end
                end
            end
        end
    end

    return effective ? mindgap_hardness(compSize) : 0
end


"""
    useNakedSet(s, setSize)

Find naked sets of exactly `setSize` cells in compartments (and rows/columns).
If `setSize` cells contain only `setSize` candidates total, remove those from other cells.
Returns `naked_set_hardness(setSize)` if progress was made, else 0.
"""
function useNakedSet(s::Str8ts, setSize::Int)
    # In-compartment naked sets
    for comp in vcat(s.rowCompartments, s.colCompartments)
        if length(comp) <= setSize
            continue
        end

        unsolved = [(r, c) for (r, c) in comp if !s.solved[r, c]]
        if length(unsolved) <= setSize
            continue
        end

        smallCells = [(r, c) for (r, c) in unsolved if length(s.candidates[r, c]) <= setSize]

        for subset in combinations(smallCells, setSize)
            unionCands = BitSet()
            for (r, c) in subset
                union!(unionCands, s.candidates[r, c])
            end

            if length(unionCands) == setSize
                effective = false
                for (r, c) in comp
                    if !((r, c) in subset) && !s.solved[r, c]
                        for n in collect(unionCands)
                            if n in s.candidates[r, c]
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
                if effective
                    return naked_set_hardness(setSize)
                end
            end
        end
    end

    # Cross-compartment naked sets within rows
    for r in 1:9
        unsolved = [(r, c) for c in 1:9 if !s.isBlack[r, c] && !s.solved[r, c]]
        if length(unsolved) <= setSize
            continue
        end

        smallCells = [(rr, c) for (rr, c) in unsolved if length(s.candidates[rr, c]) <= setSize]

        for subset in combinations(smallCells, setSize)
            unionCands = BitSet()
            for (rr, c) in subset
                union!(unionCands, s.candidates[rr, c])
            end

            if length(unionCands) == setSize
                effective = false
                for c in 1:9
                    if !s.isBlack[r, c] && !s.solved[r, c] && !((r, c) in subset)
                        for n in collect(unionCands)
                            if n in s.candidates[r, c]
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
                if effective
                    return naked_set_hardness(setSize)
                end
            end
        end
    end

    # Cross-compartment naked sets within columns
    for c in 1:9
        unsolved = [(r, c) for r in 1:9 if !s.isBlack[r, c] && !s.solved[r, c]]
        if length(unsolved) <= setSize
            continue
        end

        smallCells = [(r, cc) for (r, cc) in unsolved if length(s.candidates[r, cc]) <= setSize]

        for subset in combinations(smallCells, setSize)
            unionCands = BitSet()
            for (r, cc) in subset
                union!(unionCands, s.candidates[r, cc])
            end

            if length(unionCands) == setSize
                effective = false
                for r in 1:9
                    if !s.isBlack[r, c] && !s.solved[r, c] && !((r, c) in subset)
                        for n in collect(unionCands)
                            if n in s.candidates[r, c]
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
                if effective
                    return naked_set_hardness(setSize)
                end
            end
        end
    end

    return 0
end


"""
    useHiddenSet(s, setSize)

Find hidden sets of exactly `setSize` sure candidates appearing in exactly `setSize` cells.
Remove other candidates from those cells.
Returns `hidden_set_hardness(setSize)` if progress was made, else 0.
"""
function useHiddenSet(s::Str8ts, setSize::Int)
    # In-compartment hidden sets
    for comp in vcat(s.rowCompartments, s.colCompartments)
        if length(comp) <= setSize
            continue
        end

        ranges = getCompartmentRanges(s, comp)
        sure = getSureCandidates(ranges, length(comp))

        if length(sure) < setSize
            continue
        end

        candidateCells = Dict{Int, Vector{Tuple{Int,Int}}}()
        for n in sure
            candidateCells[n] = [(r, c) for (r, c) in comp if n in s.candidates[r, c]]
        end

        for subset in combinations(collect(sure), setSize)
            cells = Set{Tuple{Int,Int}}()
            for n in subset
                for cell in candidateCells[n]
                    push!(cells, cell)
                end
            end

            if length(cells) == setSize
                effective = false
                for (r, c) in cells
                    if !s.solved[r, c]
                        for n in collect(s.candidates[r, c])
                            if !(n in subset)
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
                if effective
                    return hidden_set_hardness(setSize)
                end
            end
        end
    end

    # Cross-compartment hidden sets within rows
    for r in 1:9
        whiteCells = [(r, c) for c in 1:9 if !s.isBlack[r, c]]
        if length(whiteCells) <= setSize
            continue
        end

        allCands = BitSet()
        for (rr, c) in whiteCells
            union!(allCands, s.candidates[rr, c])
        end

        for subset in combinations(collect(allCands), setSize)
            cells = Set{Tuple{Int,Int}}()
            for n in subset
                for (rr, c) in whiteCells
                    if n in s.candidates[rr, c]
                        push!(cells, (rr, c))
                    end
                end
            end

            if length(cells) == setSize
                allSure = all(n -> begin
                    compIdx = s.cellToRowCompartment[r, first(c for (_, c) in cells if n in s.candidates[r, c])]
                    comp = s.rowCompartments[compIdx]
                    compRanges = getCompartmentRanges(s, comp)
                    compSure = getSureCandidates(compRanges, length(comp))
                    n in compSure
                end, subset)

                if allSure
                    effective = false
                    for (rr, c) in cells
                        if !s.solved[rr, c]
                            for n in collect(s.candidates[rr, c])
                                if !(n in subset)
                                    remCandidate!(s, rr, c, n)
                                    effective = true
                                end
                            end
                        end
                    end
                    if effective
                        return hidden_set_hardness(setSize)
                    end
                end
            end
        end
    end

    return 0
end


"""
    useLockedCompartments(s)

Handle locked compartments - when compartments share ranges and constrain each other.
"""
function useLockedCompartments(s::Str8ts)
    effective = false
    
    # Check row compartments that could lock each other
    for r in 1:9
        comps = [comp for comp in s.rowCompartments if !isempty(comp) && comp[1][1] == r]
        
        if length(comps) >= 2
            for i in 1:length(comps)
                for j in i+1:length(comps)
                    eff = checkLockedCompartments!(s, comps[i], comps[j])
                    effective = effective || eff
                end
            end
        end
    end

    # Check column compartments
    for c in 1:9
        comps = [comp for comp in s.colCompartments if !isempty(comp) && comp[1][2] == c]

        if length(comps) >= 2
            for i in 1:length(comps)
                for j in i+1:length(comps)
                    eff = checkLockedCompartments!(s, comps[i], comps[j])
                    effective = effective || eff
                end
            end
        end
    end

    return effective ? H_LOCKED : 0
end


function checkLockedCompartments!(s::Str8ts, comp1::Compartment, comp2::Compartment)
    effective = false
    
    size1 = length(comp1)
    size2 = length(comp2)
    
    ranges1 = getCompartmentRanges(s, comp1)
    ranges2 = getCompartmentRanges(s, comp2)
    
    if isempty(ranges1) || isempty(ranges2)
        return false
    end
    
    # Check if comp1's ranges constrain comp2 and vice versa
    # If comp1 must use certain numbers, those are not available to comp2 in the row
    sure1 = getSureCandidates(ranges1, size1)
    sure2 = getSureCandidates(ranges2, size2)
    
    # Remove sure candidates of one compartment from the other (if in same row/col)
    row1 = comp1[1][1]
    row2 = comp2[1][1]
    col1 = comp1[1][2]
    col2 = comp2[1][2]
    
    if row1 == row2 || col1 == col2
        for n in sure1
            for (r, c) in comp2
                if n in s.candidates[r, c]
                    remCandidate!(s, r, c, n)
                    effective = true
                end
            end
        end
        
        for n in sure2
            for (r, c) in comp1
                if n in s.candidates[r, c]
                    remCandidate!(s, r, c, n)
                    effective = true
                end
            end
        end
    end
    
    return effective
end


"""
    useSureCandidates(s)

Remove sure candidates of a compartment from other compartments in the same row/column.
"""
function useSureCandidates(s::Str8ts)
    effective = false
    
    # For each row, find sure candidates of each compartment and remove from others
    for r in 1:9
        comps = [comp for comp in s.rowCompartments if !isempty(comp) && comp[1][1] == r]
        
        for comp in comps
            ranges = getCompartmentRanges(s, comp)
            sure = getSureCandidates(ranges, length(comp))
            
            # Remove sure candidates from other cells in the row
            for c in 1:9
                if !s.isBlack[r, c]
                    compIdx = s.cellToRowCompartment[r, c]
                    if s.rowCompartments[compIdx] != comp
                        for n in sure
                            if n in s.candidates[r, c]
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    # Same for columns
    for c in 1:9
        comps = [comp for comp in s.colCompartments if !isempty(comp) && comp[1][2] == c]
        
        for comp in comps
            ranges = getCompartmentRanges(s, comp)
            sure = getSureCandidates(ranges, length(comp))
            
            # Remove sure candidates from other cells in the column
            for r in 1:9
                if !s.isBlack[r, c]
                    compIdx = s.cellToColCompartment[r, c]
                    if s.colCompartments[compIdx] != comp
                        for n in sure
                            if n in s.candidates[r, c]
                                remCandidate!(s, r, c, n)
                                effective = true
                            end
                        end
                    end
                end
            end
        end
    end

    return effective ? H_SURE_CANDIDATES : 0
end


# ============================================================================
# SEA CREATURES: X-Wing, Swordfish, Jellyfish, Starfish
# ============================================================================

"""
    useXWing(s)

Find X-Wing patterns: a sure candidate appears in exactly 2 cells in 2 rows,
and those cells are in the same 2 columns. Remove from other cells in those columns.
(Or vice versa with columns and rows.)
"""
function useXWing(s::Str8ts)
    return useSeaCreature(s, 2)
end


"""
    useSwordfish(s)

Find Swordfish patterns: 3 rows/columns where a sure candidate appears in the same 3 columns/rows.
"""
function useSwordfish(s::Str8ts)
    return useSeaCreature(s, 3)
end


"""
    useJellyfish(s)

Find Jellyfish patterns: 4 rows/columns.
"""
function useJellyfish(s::Str8ts)
    return useSeaCreature(s, 4)
end


"""
    useStarfish(s)

Find Starfish patterns: 5 rows/columns.
"""
function useStarfish(s::Str8ts)
    return useSeaCreature(s, 5)
end


function useSeaCreature(s::Str8ts, n::Int)
    effective = false
    
    # Row-based (eliminate from columns)
    for num in 1:9
        # Find rows where num is a sure candidate
        sureRows = Int[]
        rowCells = Dict{Int, Vector{Int}}()  # row -> columns where num appears
        
        for r in 1:9
            # Check if num is sure in any compartment of this row
            isSure = false
            cols = Int[]
            
            for comp in s.rowCompartments
                if isempty(comp) || comp[1][1] != r
                    continue
                end
                
                ranges = getCompartmentRanges(s, comp)
                sure = getSureCandidates(ranges, length(comp))
                
                if num in sure
                    isSure = true
                    for (rr, c) in comp
                        if num in s.candidates[rr, c]
                            push!(cols, c)
                        end
                    end
                end
            end
            
            if isSure && 1 <= length(cols) <= n
                push!(sureRows, r)
                rowCells[r] = cols
            end
        end
        
        # Try all combinations of n rows
        for rows in combinations(sureRows, n)
            # Collect all columns involved
            allCols = Set{Int}()
            for r in rows
                for c in rowCells[r]
                    push!(allCols, c)
                end
            end
            
            if length(allCols) == n
                # Found a sea creature! Remove num from other cells in these columns
                for c in allCols
                    for r in 1:9
                        if !(r in rows) && !s.isBlack[r, c] && num in s.candidates[r, c]
                            remCandidate!(s, r, c, num)
                            effective = true
                        end
                    end
                end

                if effective
                    return sea_creature_hardness(n)
                end
            end
        end
    end
    
    # Column-based (eliminate from rows)
    for num in 1:9
        sureCols = Int[]
        colCells = Dict{Int, Vector{Int}}()  # col -> rows where num appears
        
        for c in 1:9
            isSure = false
            rows = Int[]
            
            for comp in s.colCompartments
                if isempty(comp) || comp[1][2] != c
                    continue
                end
                
                ranges = getCompartmentRanges(s, comp)
                sure = getSureCandidates(ranges, length(comp))
                
                if num in sure
                    isSure = true
                    for (r, cc) in comp
                        if num in s.candidates[r, cc]
                            push!(rows, r)
                        end
                    end
                end
            end
            
            if isSure && 1 <= length(rows) <= n
                push!(sureCols, c)
                colCells[c] = rows
            end
        end
        
        for cols in combinations(sureCols, n)
            allRows = Set{Int}()
            for c in cols
                for r in colCells[c]
                    push!(allRows, r)
                end
            end
            
            if length(allRows) == n
                for r in allRows
                    for c in 1:9
                        if !(c in cols) && !s.isBlack[r, c] && num in s.candidates[r, c]
                            remCandidate!(s, r, c, num)
                            effective = true
                        end
                    end
                end

                if effective
                    return sea_creature_hardness(n)
                end
            end
        end
    end

    return 0
end


# ============================================================================
# ADVANCED STRATEGIES
# ============================================================================

"""
    useSettisRule(s)

Setti's rule: a number must appear in the same number of rows and columns.
Implemented via BCA-style classification:
- sure (present or guaranteed by compartment ranges)
- possible (may appear)
- missing (cannot appear)
"""
@inline function settiRowHasPlaced(s::Str8ts, r::Int, num::Int)
    for c in 1:9
        if s.numbers[r, c] == num && (s.solved[r, c] || (s.isBlack[r, c] && s.numbers[r, c] != 0))
            return true
        end
    end
    return false
end

@inline function settiColHasPlaced(s::Str8ts, c::Int, num::Int)
    for r in 1:9
        if s.numbers[r, c] == num && (s.solved[r, c] || (s.isBlack[r, c] && s.numbers[r, c] != 0))
            return true
        end
    end
    return false
end

function settiRowSure(s::Str8ts, r::Int, num::Int)
    settiRowHasPlaced(s, r, num) && return true

    for comp in s.rowCompartments
        if isempty(comp) || comp[1][1] != r
            continue
        end
        ranges = getCompartmentRanges(s, comp)
        sure = getSureCandidates(ranges, length(comp))
        num in sure && return true
    end
    return false
end

function settiColSure(s::Str8ts, c::Int, num::Int)
    settiColHasPlaced(s, c, num) && return true

    for comp in s.colCompartments
        if isempty(comp) || comp[1][2] != c
            continue
        end
        ranges = getCompartmentRanges(s, comp)
        sure = getSureCandidates(ranges, length(comp))
        num in sure && return true
    end
    return false
end

function settiStatuses(s::Str8ts, num::Int; forcedMissingRows::Set{Int}=Set{Int}(), forcedMissingCols::Set{Int}=Set{Int}())
    rowStatus = fill(:missing, 9)
    colStatus = fill(:missing, 9)

    for r in forcedMissingRows
        settiRowHasPlaced(s, r, num) && return (rowStatus, colStatus, false)
    end
    for c in forcedMissingCols
        settiColHasPlaced(s, c, num) && return (rowStatus, colStatus, false)
    end

    for r in 1:9
        if r in forcedMissingRows
            rowStatus[r] = :missing
            continue
        end

        if settiRowSure(s, r, num)
            rowStatus[r] = :sure
            continue
        end

        possible = false
        for c in 1:9
            if c in forcedMissingCols
                continue
            end
            if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
                possible = true
                break
            end
        end
        rowStatus[r] = possible ? :possible : :missing
    end

    for c in 1:9
        if c in forcedMissingCols
            colStatus[c] = :missing
            continue
        end

        if settiColSure(s, c, num)
            colStatus[c] = :sure
            continue
        end

        possible = false
        for r in 1:9
            if r in forcedMissingRows
                continue
            end
            if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
                possible = true
                break
            end
        end
        colStatus[c] = possible ? :possible : :missing
    end

    return (rowStatus, colStatus, true)
end

@inline settiMissingBounds(status::Vector{Symbol}) = (count(==(:missing), status), count(==(:missing), status) + count(==(:possible), status))
@inline settiPossibleIndices(status::Vector{Symbol}) = [i for i in 1:9 if status[i] === :possible]

function settiRemoveFromRow!(s::Str8ts, r::Int, num::Int)
    effective = false
    for c in 1:9
        if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
            remCandidate!(s, r, c, num)
            effective = true
        end
    end
    return effective
end

function settiRemoveFromCol!(s::Str8ts, c::Int, num::Int)
    effective = false
    for r in 1:9
        if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
            remCandidate!(s, r, c, num)
            effective = true
        end
    end
    return effective
end

function settiPlaceIfSingleInRow!(s::Str8ts, r::Int, num::Int)
    if settiRowHasPlaced(s, r, num)
        return false
    end
    cells = Tuple{Int, Int}[]
    for c in 1:9
        if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
            push!(cells, (r, c))
        end
    end
    if length(cells) == 1
        add!(s, cells[1][1], cells[1][2], num)
        return true
    end
    return false
end

function settiPlaceIfSingleInCol!(s::Str8ts, c::Int, num::Int)
    if settiColHasPlaced(s, c, num)
        return false
    end
    cells = Tuple{Int, Int}[]
    for r in 1:9
        if !s.isBlack[r, c] && !s.solved[r, c] && num in s.candidates[r, c]
            push!(cells, (r, c))
        end
    end
    if length(cells) == 1
        add!(s, cells[1][1], cells[1][2], num)
        return true
    end
    return false
end

function useSettisRule(s::Str8ts)
    effective = false

    for num in 1:9
        changed = true
        while changed
            changed = false

            rowStatus, colStatus, valid = settiStatuses(s, num)
            valid || break

            minRows, maxRows = settiMissingBounds(rowStatus)
            minCols, maxCols = settiMissingBounds(colStatus)

            lo = max(minRows, minCols)
            hi = min(maxRows, maxCols)
            lo > hi && break

            if lo == hi
                missingCount = lo
                possibleRows = settiPossibleIndices(rowStatus)
                possibleCols = settiPossibleIndices(colStatus)

                if maxRows == missingCount
                    for r in possibleRows
                        if settiRemoveFromRow!(s, r, num)
                            effective = true
                            changed = true
                        end
                    end
                end

                if maxCols == missingCount
                    for c in possibleCols
                        if settiRemoveFromCol!(s, c, num)
                            effective = true
                            changed = true
                        end
                    end
                end

                if minRows == missingCount
                    for r in possibleRows
                        if settiPlaceIfSingleInRow!(s, r, num)
                            effective = true
                            changed = true
                        end
                    end
                end

                if minCols == missingCount
                    for c in possibleCols
                        if settiPlaceIfSingleInCol!(s, c, num)
                            effective = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    return effective ? H_SETTI : 0
end


"""
    useSettiConsider(s)

Setti considerations using one-axis what-if checks:
if assuming a possible-missing row/column causes Setti count contradiction,
that unit must be present.
"""
function useSettiConsider(s::Str8ts)
    effective = false

    for num in 1:9
        _, colStatus, valid = settiStatuses(s, num)
        valid || continue
        for c in settiPossibleIndices(colStatus)
            rowHyp, colHyp, ok = settiStatuses(s, num, forcedMissingCols=Set([c]))
            if !ok
                if settiPlaceIfSingleInCol!(s, c, num)
                    effective = true
                    return H_SETTI_CONSIDER
                end
                continue
            end

            minRows, maxRows = settiMissingBounds(rowHyp)
            minCols, maxCols = settiMissingBounds(colHyp)
            lo = max(minRows, minCols)
            hi = min(maxRows, maxCols)

            if lo > hi
                if settiPlaceIfSingleInCol!(s, c, num)
                    effective = true
                    return H_SETTI_CONSIDER
                end
            end
        end

        rowStatus, _, valid2 = settiStatuses(s, num)
        valid2 || continue
        for r in settiPossibleIndices(rowStatus)
            rowHyp, colHyp, ok = settiStatuses(s, num, forcedMissingRows=Set([r]))
            if !ok
                if settiPlaceIfSingleInRow!(s, r, num)
                    effective = true
                    return H_SETTI_CONSIDER
                end
                continue
            end

            minRows, maxRows = settiMissingBounds(rowHyp)
            minCols, maxCols = settiMissingBounds(colHyp)
            lo = max(minRows, minCols)
            hi = min(maxRows, maxCols)

            if lo > hi
                if settiPlaceIfSingleInRow!(s, r, num)
                    effective = true
                    return H_SETTI_CONSIDER
                end
            end
        end
    end

    return effective ? H_SETTI_CONSIDER : 0
end


"""
    useSettiSet(s)

Combined Settis on digit sets (pairs/triples):
sum the missing-count ranges across digits and enforce equal total
missing counts between rows and columns.
"""
function useSettiSet(s::Str8ts)
    effective = false

    for setSize in 2:3
        for digits in combinations(collect(1:9), setSize)
            rowByDigit = Dict{Int, Vector{Symbol}}()
            colByDigit = Dict{Int, Vector{Symbol}}()
            valid = true

            for d in digits
                rowStatus, colStatus, ok = settiStatuses(s, d)
                if !ok
                    valid = false
                    break
                end
                rowByDigit[d] = rowStatus
                colByDigit[d] = colStatus
            end

            valid || continue

            rowMin = 0
            rowMax = 0
            colMin = 0
            colMax = 0

            for d in digits
                mnR, mxR = settiMissingBounds(rowByDigit[d])
                mnC, mxC = settiMissingBounds(colByDigit[d])
                rowMin += mnR
                rowMax += mxR
                colMin += mnC
                colMax += mxC
            end

            lo = max(rowMin, colMin)
            hi = min(rowMax, colMax)
            lo > hi && continue

            if lo == hi
                totalMissing = lo

                if rowMax == totalMissing
                    for d in digits
                        for r in settiPossibleIndices(rowByDigit[d])
                            if settiRemoveFromRow!(s, r, d)
                                effective = true
                            end
                        end
                    end
                end

                if colMax == totalMissing
                    for d in digits
                        for c in settiPossibleIndices(colByDigit[d])
                            if settiRemoveFromCol!(s, c, d)
                                effective = true
                            end
                        end
                    end
                end

                if rowMin == totalMissing
                    for d in digits
                        for r in settiPossibleIndices(rowByDigit[d])
                            if settiPlaceIfSingleInRow!(s, r, d)
                                effective = true
                            end
                        end
                    end
                end

                if colMin == totalMissing
                    for d in digits
                        for c in settiPossibleIndices(colByDigit[d])
                            if settiPlaceIfSingleInCol!(s, c, d)
                                effective = true
                            end
                        end
                    end
                end
            end

            if effective
                return H_SETTI_SET
            end
        end
    end

    return effective ? H_SETTI_SET : 0
end


"""
    useUniqueSolutionConstraint(s)

Avoid positions that would lead to multiple solutions.
Detect unique rectangles and similar deadly patterns.
"""
function useUniqueSolutionConstraint(s::Str8ts)
    effective = false
    
    # Look for unique rectangles: 4 cells forming a rectangle where 
    # 3 cells have the same 2 candidates - the 4th must have additional candidates to avoid ambiguity
    for r1 in 1:8
        for r2 in r1+1:9
            for c1 in 1:8
                for c2 in c1+1:9
                    cells = [(r1, c1), (r1, c2), (r2, c1), (r2, c2)]
                    
                    # All must be white unsolved cells
                    if any(s.isBlack[r, c] || s.solved[r, c] for (r, c) in cells)
                        continue
                    end
                    
                    # Check if they could form a UR
                    candidateSets = [s.candidates[r, c] for (r, c) in cells]
                    
                    # Count cells with exactly 2 candidates
                    twoCandidate = [cs for cs in candidateSets if length(cs) == 2]
                    
                    if length(twoCandidate) >= 3
                        # Find the pair that appears most
                        pairCounts = Dict{BitSet, Int}()
                        for cs in twoCandidate
                            pairCounts[cs] = get(pairCounts, cs, 0) + 1
                        end
                        
                        for (pair, count) in pairCounts
                            if count >= 3
                                # Find the 4th cell
                                for (i, (r, c)) in enumerate(cells)
                                    cs = candidateSets[i]
                                    if issubset(pair, cs) && length(cs) > 2
                                        # This cell can break the deadly pattern
                                        # Remove the pair candidates, keeping only extras
                                        extras = setdiff(cs, pair)
                                        if !isempty(extras)
                                            for n in collect(pair)
                                                remCandidate!(s, r, c, n)
                                                effective = true
                                            end
                                        end
                                    elseif cs == pair && count < 4
                                        # This cell must NOT be in the pair
                                        # Actually this is the problem cell...
                                    end
                                end
                            end
                        end
                    end
                    
                    if effective
                        return H_UNIQUE
                    end
                end
            end
        end
    end

    # Check for deadly patterns in compartments
    # If swapping two numbers in a compartment gives the same solution elsewhere, avoid that
    for comp in vcat(s.rowCompartments, s.colCompartments)
        size = length(comp)
        if size < 2
            continue
        end
        
        # Find cells with exactly 2 candidates that share the same pair
        pairCells = Dict{BitSet, Vector{Tuple{Int,Int}}}()
        for (r, c) in comp
            if !s.solved[r, c] && length(s.candidates[r, c]) == 2
                pair = s.candidates[r, c]
                if !haskey(pairCells, pair)
                    pairCells[pair] = []
                end
                push!(pairCells[pair], (r, c))
            end
        end
        
        for (pair, cells) in pairCells
            if length(cells) == 2
                # Two cells with same pair in compartment
                # Check if they also share a compartment in the other direction
                # and form a deadly pattern
            end
        end
    end

    return effective ? H_UNIQUE : 0
end


"""
    useYWing(s)

Y-Wing: base cell with 2 candidates XY, two wing cells with XZ and YZ,
eliminate Z from cells seen by both wings.
"""
function useYWing(s::Str8ts)
    effective = false
    
    # Find potential base cells (2 candidates)
    for r in 1:9
        for c in 1:9
            if s.isBlack[r, c] || s.solved[r, c]
                continue
            end
            if length(s.candidates[r, c]) != 2
                continue
            end
            
            baseCands = collect(s.candidates[r, c])
            x, y = baseCands[1], baseCands[2]
            
            # Find wing cells that share row or column with base
            # Wing1 must have X and some Z (not Y)
            # Wing2 must have Y and same Z
            
            # Cells in same row or column as base
            neighbors = Set{Tuple{Int,Int}}()
            for cc in 1:9
                if cc != c && !s.isBlack[r, cc] && !s.solved[r, cc]
                    push!(neighbors, (r, cc))
                end
            end
            for rr in 1:9
                if rr != r && !s.isBlack[rr, c] && !s.solved[rr, c]
                    push!(neighbors, (rr, c))
                end
            end
            
            # Find potential wings
            for (r1, c1) in neighbors
                cands1 = s.candidates[r1, c1]
                if length(cands1) != 2
                    continue
                end
                
                # Check if cands1 shares exactly one candidate with base
                common1 = intersect(cands1, BitSet([x, y]))
                if length(common1) != 1
                    continue
                end
                
                shared1 = first(common1)
                z = first(setdiff(cands1, common1))
                
                # Find wing2 with the other base candidate and z
                otherBase = shared1 == x ? y : x
                
                for (r2, c2) in neighbors
                    if (r2, c2) == (r1, c1)
                        continue
                    end
                    
                    cands2 = s.candidates[r2, c2]
                    if cands2 != BitSet([otherBase, z])
                        continue
                    end
                    
                    # Found Y-Wing! Base at (r,c) with XY, wings at (r1,c1) with Xz/Yz, (r2,c2) with Yz/Xz
                    # Eliminate z from cells seen by both wings
                    
                    # Cells seen by wing1
                    seenBy1 = Set{Tuple{Int,Int}}()
                    for cc in 1:9
                        if !s.isBlack[r1, cc]
                            push!(seenBy1, (r1, cc))
                        end
                    end
                    for rr in 1:9
                        if !s.isBlack[rr, c1]
                            push!(seenBy1, (rr, c1))
                        end
                    end
                    
                    # Cells seen by wing2
                    seenBy2 = Set{Tuple{Int,Int}}()
                    for cc in 1:9
                        if !s.isBlack[r2, cc]
                            push!(seenBy2, (r2, cc))
                        end
                    end
                    for rr in 1:9
                        if !s.isBlack[rr, c2]
                            push!(seenBy2, (rr, c2))
                        end
                    end
                    
                    # Cells seen by both
                    seenByBoth = intersect(seenBy1, seenBy2)
                    
                    # Remove z from cells seen by both (except wings and base)
                    for (rr, cc) in seenByBoth
                        if (rr, cc) != (r, c) && (rr, cc) != (r1, c1) && (rr, cc) != (r2, c2)
                            if !s.solved[rr, cc] && z in s.candidates[rr, cc]
                                remCandidate!(s, rr, cc, z)
                                effective = true
                            end
                        end
                    end
                    
                    if effective
                        return H_YWING
                    end
                end
            end
        end
    end

    return 0
end


function propagateWithoutBinaryGuess!(s::Str8ts)
    while !isDone(s) && isValid(s)
        progress = false
        for spec in SOLVE_STRATEGY_ORDER
            if spec.kind === :binary_guess
                continue
            end

            h = applyOrderedStrategy!(s, spec.kind, spec.param)
            if h > 0
                progress = true
                break
            end
        end

        progress || break
    end
end


function collectTrialRemovals(base::Str8ts, trial::Str8ts)
    removed = Dict{Tuple{Int, Int}, BitSet}()

    for r in 1:9
        for c in 1:9
            if base.isBlack[r, c] || base.solved[r, c]
                continue
            end

            missing = BitSet()
            for n in base.candidates[r, c]
                if !(n in trial.candidates[r, c])
                    push!(missing, n)
                end
            end

            if !isempty(missing)
                removed[(r, c)] = missing
            end
        end
    end

    return removed
end


"""
    useBinaryGuess(s)

Try one-level binary contradiction checking on cells with exactly two candidates.
For each such cell, assume one candidate, propagate deterministic strategies (excluding
binary_guess), and check validity. If one assumption leads to contradiction and the
other does not, place the non-contradicting candidate.
"""
function useBinaryGuess(s::Str8ts)
    for r in 1:9
        for c in 1:9
            if s.isBlack[r, c] || s.solved[r, c] || length(s.candidates[r, c]) != 2
                continue
            end

            vals = collect(s.candidates[r, c])
            sort!(vals)

            contradiction = falses(2)
            trials = Vector{Str8ts}(undef, 2)

            for i in 1:2
                trial = deepcopy(s)
                add!(trial, r, c, vals[i])
                propagateWithoutBinaryGuess!(trial)
                contradiction[i] = !isValid(trial)
                trials[i] = trial
            end

            if contradiction[1] != contradiction[2]
                chosen = contradiction[1] ? vals[2] : vals[1]
                add!(s, r, c, chosen)
                return H_BINARY_GUESS
            end

            if !contradiction[1] && !contradiction[2]
                removed1 = collectTrialRemovals(s, trials[1])
                removed2 = collectTrialRemovals(s, trials[2])

                effective = false
                for (cell, rem1) in removed1
                    if !haskey(removed2, cell)
                        continue
                    end

                    common = intersect(rem1, removed2[cell])
                    if isempty(common)
                        continue
                    end

                    (rr, cc) = cell
                    for n in common
                        if n in s.candidates[rr, cc]
                            remCandidate!(s, rr, cc, n)
                            effective = true
                        end
                    end
                end

                if effective
                    return H_BINARY_GUESS
                end
            end
        end
    end

    return 0
end


# ============================================================================
# CONVENIENCE WRAPPERS (all sizes, first-success)
# ============================================================================

useCompartmentRangeCheck(s::Str8ts) = (for k in 2:9; h = useCompartmentRangeCheck(s, k); h > 0 && return h; end; return 0)
useStrandedDigits(s::Str8ts)        = (for k in 2:9; h = useStrandedDigits(s, k);        h > 0 && return h; end; return 0)
useSplitCompartment(s::Str8ts)      = (for k in 3:9; h = useSplitCompartment(s, k);      h > 0 && return h; end; return 0)
useMindTheGap(s::Str8ts)            = (for k in 2:9; h = useMindTheGap(s, k);            h > 0 && return h; end; return 0)
useNakedSet(s::Str8ts)              = (for k in 2:5; h = useNakedSet(s, k);              h > 0 && return h; end; return 0)
useHiddenSet(s::Str8ts)             = (for k in 2:5; h = useHiddenSet(s, k);             h > 0 && return h; end; return 0)


const SOLVE_STRATEGY_ORDER = let
    specs = NamedTuple{(:label, :hardness, :kind, :param, :order), Tuple{String, Int, Symbol, Int, Int}}[]
    order = 0

    order += 1
    push!(specs, (label="Single", hardness=H_SINGLE, kind=:single, param=0, order=order))

    order += 1
    push!(specs, (label="Sure candidates", hardness=H_SURE_CANDIDATES, kind=:sure, param=0, order=order))

    for k in 2:9
        order += 1
        push!(specs, (label="Stranded digits (comp size $k)", hardness=stranded_hardness(k), kind=:stranded, param=k, order=order))
    end

    for k in 3:9
        order += 1
        push!(specs, (label="Split compartment (comp size $k)", hardness=split_hardness(k), kind=:split, param=k, order=order))
    end

    for k in 2:9
        order += 1
        push!(specs, (label="Mind the gap (comp size $k)", hardness=mindgap_hardness(k), kind=:mindgap, param=k, order=order))
    end

    for k in 2:9
        order += 1
        push!(specs, (label="Range check (comp size $k)", hardness=range_check_hardness(k), kind=:range_check, param=k, order=order))
    end

    for k in 2:5
        order += 1
        push!(specs, (label="Naked set (size $k)", hardness=naked_set_hardness(k), kind=:naked_set, param=k, order=order))
    end

    for k in 2:5
        order += 1
        push!(specs, (label="Hidden set (size $k)", hardness=hidden_set_hardness(k), kind=:hidden_set, param=k, order=order))
    end

    order += 1
    push!(specs, (label="Locked compartments", hardness=H_LOCKED, kind=:locked, param=0, order=order))

    for n in 2:5
        order += 1
        push!(specs, (label="Sea creature (n=$n)", hardness=sea_creature_hardness(n), kind=:sea, param=n, order=order))
    end

    order += 1
    push!(specs, (label="Unique solution constraint", hardness=H_UNIQUE, kind=:unique, param=0, order=order))

    order += 1
    push!(specs, (label="Setti's rule", hardness=H_SETTI, kind=:setti, param=0, order=order))

    order += 1
    push!(specs, (label="Setti considerations", hardness=H_SETTI_CONSIDER, kind=:setti_consider, param=0, order=order))

    order += 1
    push!(specs, (label="Combined Settis", hardness=H_SETTI_SET, kind=:setti_set, param=0, order=order))

    order += 1
    push!(specs, (label="Y-Wing", hardness=H_YWING, kind=:ywing, param=0, order=order))

    order += 1
    push!(specs, (label="Binary guess", hardness=H_BINARY_GUESS, kind=:binary_guess, param=0, order=order))

    sort!(specs, by = s -> (s.hardness, s.order))
    specs
end


function applyOrderedStrategy!(s::Str8ts, kind::Symbol, param::Int)
    if kind === :single
        return useSingle(s)
    elseif kind === :sure
        return useSureCandidates(s)
    elseif kind === :stranded
        return useStrandedDigits(s, param)
    elseif kind === :split
        return useSplitCompartment(s, param)
    elseif kind === :mindgap
        return useMindTheGap(s, param)
    elseif kind === :range_check
        return useCompartmentRangeCheck(s, param)
    elseif kind === :naked_set
        return useNakedSet(s, param)
    elseif kind === :hidden_set
        return useHiddenSet(s, param)
    elseif kind === :locked
        return useLockedCompartments(s)
    elseif kind === :sea
        return useSeaCreature(s, param)
    elseif kind === :unique
        return useUniqueSolutionConstraint(s)
    elseif kind === :setti
        return useSettisRule(s)
    elseif kind === :setti_consider
        return useSettiConsider(s)
    elseif kind === :setti_set
        return useSettiSet(s)
    elseif kind === :ywing
        return useYWing(s)
    elseif kind === :binary_guess
        return useBinaryGuess(s)
    end

    return 0
end


"""
    solveHuman!(s; verbose=true)

Solve the Str8ts puzzle using human-like strategies in strict ascending hardness order.
Returns a Vector{Int} of per-move hardness values (0-100 scale).
"""
function solveHuman!(s::Str8ts; verbose=true)
    move_hardnesses = Int[]

    while !isDone(s) && isValid(s)
        progress = false
        for spec in SOLVE_STRATEGY_ORDER
            h = applyOrderedStrategy!(s, spec.kind, spec.param)
            if h > 0
                verbose && println("$(spec.label) (h=$h)")
                push!(move_hardnesses, h)
                progress = true
                break
            end
        end

        progress || break
    end

    if !isValid(s)
        println("Puzzle is invalid/unsolvable")
        return [-1]
    end

    if !isDone(s)
        verbose && println("Could not solve puzzle with available strategies")
        push!(move_hardnesses, H_UNSOLVABLE)
    end

    return move_hardnesses
end

"""
    puzzleHardness(moves::Vector{Int})

Summarise the move-hardness vector from solveHuman!() into a single puzzle difficulty
score: the maximum hardness of any individual move (0 for a trivially pre-solved
puzzle, H_UNSOLVABLE if unsolvable).
"""
function puzzleHardness(moves::Vector{Int})
    isempty(moves) && return 0
    return maximum(moves)
end


"""
    getSolution(s)

Get the solution string (81 characters) for comparison.
"""
function getSolution(s::Str8ts)
    result = ""
    for r in 1:9
        for c in 1:9
            if s.isBlack[r, c]
                if s.numbers[r, c] != 0
                    result *= string(Char('a' + s.numbers[r, c] - 1))
                else
                    result *= "#"
                end
            else
                result *= string(s.numbers[r, c])
            end
        end
    end
    return result
end


"""
    getCurrentState(s)

Get the current state string (81 characters) including unsolved cells as dots.
"""
function getCurrentState(s::Str8ts)
    result = ""
    for r in 1:9
        for c in 1:9
            if s.isBlack[r, c]
                if s.numbers[r, c] != 0
                    result *= string(Char('a' + s.numbers[r, c] - 1))
                else
                    result *= "#"
                end
            else
                if s.solved[r, c]
                    result *= string(s.numbers[r, c])
                else
                    result *= "."
                end
            end
        end
    end
    return result
end

# (c) Mia Muessig