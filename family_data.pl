% ============================================================
% family_data.pl  -  The knowledge base (data only, no logic)
% Author : Chitransh Bari   Reg No : 25MIB10062
% ============================================================
% Declared dynamic so facts can be added/removed while running,
% e.g.  ?- assertz(parent(dev, sam)).

:- dynamic person/4, parent/2, married/2, ex_spouse/2.

current_year(2026).

% person(Name, Gender, BirthYear, DeathYear)   DeathYear = alive if living
person(harish, male,   1930, 2005).
person(sita,   female, 1934, 2010).
person(mohan,  male,   1958, alive).
person(meena,  female, 1960, alive).
person(radha,  female, 1961, alive).
person(vivek,  male,   1958, alive).
person(kiran,  male,   1964, alive).
person(anita,  female, 1966, alive).
person(leela,  female, 1965, alive).
person(arjun,  male,   1985, alive).
person(isha,   female, 1986, alive).
person(neha,   female, 1988, alive).
person(rohan,  male,   1987, alive).
person(tina,   female, 1988, alive).
person(pooja,  female, 1990, alive).
person(sameer, male,   1989, alive).
person(dev,    male,   1992, alive).
person(aarav,  male,   2015, alive).
person(myra,   female, 2018, alive).

% parent(Parent, Child)  - both parents of every child are recorded
parent(harish, mohan).   parent(sita,  mohan).
parent(harish, radha).   parent(sita,  radha).
parent(harish, kiran).   parent(sita,  kiran).
parent(mohan,  arjun).   parent(meena, arjun).
parent(mohan,  neha).    parent(meena, neha).
parent(radha,  rohan).   parent(vivek, rohan).
parent(radha,  pooja).   parent(vivek, pooja).
parent(kiran,  sameer).  parent(leela, sameer).
parent(kiran,  dev).     parent(anita, dev).
parent(arjun,  aarav).   parent(isha,  aarav).
parent(rohan,  myra).    parent(tina,  myra).

% married(A, B) - current marriages;  ex_spouse(A, B) - past marriages
married(harish, sita).
married(mohan,  meena).
married(radha,  vivek).
married(kiran,  anita).
married(arjun,  isha).
married(rohan,  tina).

ex_spouse(kiran, leela).
