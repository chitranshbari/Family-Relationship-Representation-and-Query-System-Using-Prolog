# Kinship Reasoning Engine (Advanced Prolog Family Project)

An upgrade of the basic family-relationship project. Instead of only answering "who is the parent / sibling / ancestor", this engine can **name any relationship between two people automatically**, **explain its reasoning**, **validate its own data**, and **answer questions typed in English**.

- **Author:** Chitransh Bari (25MIB10062)
- **Course:** Fundamentals of AI and ML
- **Language:** SWI-Prolog 8.x or newer

## Files
| File | Purpose |
|---|---|
| `family_data.pl` | Knowledge base only: people (with gender and birth/death years), parents, marriages, ex-spouses |
| `kinship_engine.pl` | All the logic: rules, calculator, validator, grammar, statistics, tests |
| `README.md` | This document |

## How to run
```
swipl kinship_engine.pl
?- help.        % list of commands
?- demo.        % guided demonstration
?- run_tests.   % self-test suite (every line should say PASS)
```
Keep both `.pl` files in the same folder; the engine loads the data file automatically.

## What is new compared with the basic project
| # | Feature | Why it matters |
|---|---|---|
| 1 | **Relationship calculator** | Names any blood relation: `second cousin`, `first cousin once removed`, `half-brother`, `great-grandfather`, `great-aunt` |
| 2 | **In-law and ex-spouse relations** | `father-in-law`, `sister-in-law`, `ex-wife`, using marriage data |
| 3 | **Explanation facility** | `explain/2` shows the common ancestor and both paths, so the answer is justified |
| 4 | **Integrity validator** | Detects cycles, impossible age gaps, missing records, too many parents, and marriages between close relatives |
| 5 | **Natural-language questions** | `ask('Who is the aunt of aarav?')` using a DCG grammar |
| 6 | **Richer data model** | `person(Name, Gender, Birth, Death)`, so ages, generations and living status can be computed |
| 7 | **Half and full siblings** | Distinguishes by comparing parent sets |
| 8 | **Statistics and generations** | `family_stats`, `print_generations` |
| 9 | **Graphviz export** | `export_dot('family.dot')` draws the tree |
| 10 | **Self-tests** | `run_tests` covers rules, calculator, grammar and validator |

## The family in the data file
```
                 harish == sita
                       |
     +-----------------+-------------------+
     |                 |                   |
 mohan==meena     radha==vivek      kiran==anita  (ex-wife: leela)
     |                 |                   |            |
 arjun==isha,neha  rohan==tina,pooja      dev         sameer
     |                 |                (sameer is dev's half-brother)
   aarav             myra
```
`aarav` and `myra` are second cousins; `arjun` and `myra` are first cousins once removed; `sameer` and `dev` are half-brothers.

## How the relationship calculator works (the core idea)
Every blood relationship is determined by two numbers: how many generations each person is below their **nearest common ancestor**.

1. `up(Person, Ancestor, N)` finds ancestors and their distance (N = 0 is the person themself).
2. `closest_common/5` collects all common ancestors, keeps the pair of distances with the smallest total, and counts how many ancestors sit at that spot. Two ancestors means they come through a couple (a **full** relation); one means a **half** relation.
3. `name_for(Da, Db, ...)` turns the pair `(Da, Db)` into a name:

| (Da, Db) | Relationship of X to Y |
|---|---|
| (0, 1) | parent (father/mother) |
| (0, n≥2) | grandparent, great-grandparent, ... |
| (1, 0) | child; (n≥2, 0) grandchild, great-grandchild, ... |
| (1, 1) | sibling (half-sibling if one shared parent) |
| (1, n≥2) | uncle/aunt; great-uncle/aunt when n≥3 |
| (n≥2, 1) | nephew/niece; great-nephew/niece when n≥3 |
| (a≥2, b≥2) | **cousin**: degree = min(a, b) − 1, times removed = |a − b| |

Example: `aarav` is 3 generations below `harish`, and so is `myra`, so (3, 3) gives degree 2 and removed 0, which is a **second cousin**. For `arjun` and `myra` it is (2, 3): degree 1, removed 1, so **first cousin once removed**.

If no blood relation exists, `marital_relationship/3` tries spouse, ex-spouse, parent-in-law, child-in-law and sibling-in-law.

## Sample session
```prolog
?- relationship(aarav, myra, N).        % N = 'second cousin'
?- explain(arjun, myra).
%  arjun is the first cousin once removed of myra.
%  Nearest common ancestor: harish
%    path to arjun: harish -> mohan -> arjun
%    path to myra: harish -> radha -> rohan -> myra
?- ask('Who is the aunt of aarav?').    % [neha]
?- ask('How is aarav related to myra?').% [second cousin]
?- ask('How old is mohan?').            % [68]
?- family_stats.
?- validate.                            % Validation passed
```

### Try breaking the data on purpose
```prolog
?- assertz(parent(dev, harish)), validate.
%  Cycle detected: ... is their own ancestor
?- retract(parent(dev, harish)).
?- assertz(parent(ghost, dev)), validate.
%  Missing person record: ghost
?- retract(parent(ghost, dev)).
```

### Add a new person live
```prolog
?- assertz(person(sam, male, 2020, alive)), assertz(parent(dev, sam)).
?- relationship(harish, sam, N).        % great-grandfather
?- retract(parent(dev, sam)), retract(person(sam, male, 2020, alive)).
```

## Integrity checks performed by `validate`
- Every person mentioned has a `person/4` record
- No one has more than two recorded parents
- No one dies before being born
- Parents are at least 15 years older than their children
- A parent did not die more than a year before the child was born
- No one is their own ancestor (cycle detection with a "seen" list so the check itself cannot loop)
- Warning when married people are close blood relatives (distance total of 4 or less)

## Design notes and limitations
- Data lives in a separate file, so logic and data can change independently.
- Facts are `dynamic`, so they can be added or removed at runtime.
- Relationship names follow common English conventions; "removed" cousins are named by generation difference.
- Only two parents are expected per child; adoption and step-parents are not modelled.
- The grammar understands three question patterns; it is a demonstration, not full NLP.
- `relationship/3` returns the first (closest) relationship only.

## Possible future work
Adoption and step-families, date-aware queries ("who was alive in 1990?" using `alive_in/2`), reading data from CSV, a web or GUI front end, and a Python bridge (`pyswip`).
