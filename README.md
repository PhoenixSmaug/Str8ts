# Str8ts Solver

## Legal Disclaimer

This project is an independent solver for the puzzle game **Str8ts**, developed purely for educational and recreational purposes. **Str8ts** is a registered trademark of **Syndicated Puzzles Inc**. All rights to the name, branding, and associated intellectual property belong to them. The author of this project is **not affiliated, associated, authorized, endorsed by, or in any way officially connected with Syndicated Puzzles Inc.**, or any of its subsidiaries or affiliates.

The only Str8ts puzzle included in this repository is ''Str8ts9x9 Very Hard PUZ.png'' by AndrewCStuart from [the German Wikipedia page](https://de.wikipedia.org/wiki/Str8ts#/media/Datei:Str8ts9x9_Very_Hard_PUZ.png), and is licensed under the [Creative Commons Attribution-ShareAlike 3.0 Unported License (CC BY-SA 3.0)](https://creativecommons.org/licenses/by-sa/3.0/). This puzzle is used **solely as an example** to demonstrate the solver algorithm and is **not** licensed under the MIT License like the rest of the code in this repository. For full licensing details, refer to the `LICENSE` file.

## Introduction

### Rules

A Str8ts puzzle consists of a 9x9 board that must be filled according to the following rules:

1. Each white cell must be filled with a number between 1 and 9, so that each number appears at most once in each row and column.
2. Each compartment (a connected vertical or horizontal group of white cells) must contain a consecutive sequence of numbers in any order. For example, $4,2,5,3$ would be a valid solution for a compartment with four cells, while $4,2,5,1$ would not be.
3. Black cells do not have to be filled with a number. If a black cell contains a number at the beginning, this number cannot appear in a white cell in the row or column.

To summarize, Str8ts is a Sudoku modification where some cells are black and do not need to be filled and the block constraints are replaced by compartment constraints. The [German Wikipedia page](https://de.wikipedia.org/wiki/Str8ts) gives two example puzzles and their solution, which can illustrate the initially somewhat confusing rules of Str8ts.

### NP-Completeness

Str8ts generalized on an $n \times n$ board is an NP-complete problem by the following argument: For a given solution, we can verify that the three rules hold in polynomial time, so the problem is in NP. And the special case that a Str8ts puzzle contains no black cells is equivalent to a simple Latin square, where we fill each cell so that each number appears exactly once in each row and column. As proven in [“The complexity of completing partial Latin squares”](https://doi.org/10.1016/0166-218X(84)90075-1), solving a Latin square is an NP-complete problem and thus also the Str8ts problem.

### SAT Encoding

In the standard encoding of a Sudoku puzzle into SAT we have variables $x_{i, j, n}$, which are true if and only if the cell in the $i$-th row and $j$-th column contains the number $n$. Copying this approach, the rules 1 and 3 can then encoded using the following constraints:

(A) Each white cell has at least one number, an empty black cell does not have a number
```math
\forall i \in \{1, \ldots, 9\} : \forall j \in \{1, \ldots, 9\} : \begin{cases} \bigvee_{n = 1}^9 x_{i, j, n} & \text{if cell } (i, j) \text{ is white}, \\ \bigwedge_{n = 1}^9 \overline{x}_{i, j, n} & \text{if cell } (i, j) \text{ is black and empty.} \end{cases} 
```

(B) Each number appears at most once per column/row
```math
\forall n \in \{1, \ldots, 9\} : \forall i \in \{1, \ldots, 9\} : \bigwedge_{j, j^{\prime} \in \{1, \ldots, 9\}, j \neq j^{\prime}} \overline{x}_{i, j, n} \lor \overline{x}_{i, j^{\prime}, n}
```
```math
\forall n \in \{1, \ldots, 9\} : \forall j \in \{1, \ldots, 9\} : \bigwedge_{i, i^{\prime} \in \{1, \ldots, 9\}, i \neq i^{\prime}} \overline{x}_{i, j, n} \lor \overline{x}_{i^{\prime}, j, n}
```

The big challenge is the encoding of rule 2, as the requirement for consecutive numbers in arbitrary order is very hard to translate into pure boolean logic. We will side-step this problem by introducing the alternative rule 2', proving the equivalence to rule 2 and then encode the former into SAT.

2'. If a compartment of length $t$ contains the number $n$, it contains no numbers $\geq n + t$ and $\leq n - t$.

Proof that rule 2 implies 2': If a compartment contains $t$ consecutive numbers, all difference between any two entries is at most $t - 1$. Thus it can't contain $n$ and another entry $\geq n + t$ or $\leq n - t$ and so rule 2' is satisfied.

Proof that rule 2' implies 2: We choose $n$ as the smallest number contained in the compartment, meaning all other entries are larger than $n$. Since they the entries follow rule 2', we know that the remaining numbers $\{m_1, m_2, \ldots, m_{t - 1}\}$ all fulfill $n < m_i < n + t$. But there are only $t - 1$ integers $> n$ and $< n + t$, and by rule 1 all entries are pairwise distinct. This means that the remaining numbers must be exactly those integers and so form a consecutive sequence with $n$, fulfilling rule 2.

Now we encode rule 2':

(C) Compartment constraints are satisfied

For all compartments $C_m = \\{(i_{m_1}, j_{m_1}), \ldots, (i_{m_t}, j_{m_t})\\}$ we add:
```math
\forall (i, j), (i^{\prime}, j^{\prime}) \in C_m \text{ with } (i, j) \neq (i^{\prime}, j^{\prime}): \forall n \in \{1, \ldots, 9\} : \bigwedge_{n^\prime = n + t}^{9} \overline{x}_{i, j, n} \lor \overline{x}_{i^{\prime}, j^{\prime}, n^{\prime}}
```
```math
\forall (i, j), (i^{\prime}, j^{\prime}) \in C_m \text{ with } (i, j) \neq (i^{\prime}, j^{\prime}): \forall n \in \{1, \ldots, 9\} : \bigwedge_{n^\prime = 1}^{n - t} \overline{x}_{i, j, n} \lor \overline{x}_{i^{\prime}, j^{\prime}, n^{\prime}}
```

Then finally we ensure that the already placed numbers are accepted:

(D) Respect hints
```math
\forall i \in \{1, \ldots, 9\} : \forall j \in \{1, \ldots, 9\} : \begin{cases} x_{i, j, n} & \text{if cell } (i, j) \text{ starts with number } n, \\  & \text{otherwise.} \end{cases} 
```

## Code

Str8ts puzzles are inputed as a 81 character string, mapping the 81 cells starting from the top left corner to the bottom right corner. A white cell with number $n$ is simply denoted as "n", if it is empty we denote it with ".". Black cells with number $n$ are denoted as the $n$-th letter in the alphabet, so $4$ would be encoded as "d" and empty black cells are denoted with "#". In `main.jl` we give the string representation for a diabolic Str8ts puzzle as an example.

The user can use `solveSAT!(s::Str8ts)`, to encode the given Str8ts puzzle into pure SAT like described in the previous section and solve it with the [PicoSAT](https://fmv.jku.at/picosat/) SAT solver. Alternatively we provide `solveSimple!(s::Str8ts)`, which is a 70 line backtracking solver again using rule 2'. While in general the more complicated SAT approach is far faster, both algorithms solve even diabolic Str8ts in a few millseconds as demonstrated in `main.jl`.

(c) Mia Müßig
