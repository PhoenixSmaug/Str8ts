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

### Encoding


(c) Mia Müßig
