% ============================================================
% Kinship Reasoning Engine  (advanced version of the family project)
% Author : Chitransh Bari   Reg No : 25MIB10062
% Run    : swipl kinship_engine.pl      then type  ?- help.
%
% Novel features
%   1. Relationship calculator  - names ANY blood relation automatically
%                                 (e.g. "second cousin", "first cousin once removed",
%                                  "half-brother", "great-grandfather")
%   2. In-law and ex-spouse relations
%   3. Explanation facility     - shows the common ancestor and both paths
%   4. Data integrity validator - cycles, impossible ages, missing records,
%                                 close-kin marriages
%   5. Natural-language questions via a DCG grammar
%   6. Statistics and Graphviz export of the tree
%   7. Built-in self-test suite
% ============================================================

:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module(library(lists)).

:- [family_data].

% ------------------------------------------------------------
% 1. BASIC RELATIONS (the original project, now gender-aware
%    through person/4 instead of separate male/female facts)
% ------------------------------------------------------------
male(X)   :- person(X, male, _, _).
female(X) :- person(X, female, _, _).

father(X, Y) :- parent(X, Y), male(X).
mother(X, Y) :- parent(X, Y), female(X).

child(X, Y)    :- parent(Y, X).
son(X, Y)      :- child(X, Y), male(X).
daughter(X, Y) :- child(X, Y), female(X).

% Siblings share at least one parent. The cut in shares_parent/2
% stops the same pair being reported once per shared parent.
sibling(X, Y) :-
    person(X, _, _, _), person(Y, _, _, _),
    X \== Y,
    shares_parent(X, Y).

shares_parent(X, Y) :- parent(Z, X), parent(Z, Y), !.

% Full siblings have identical parent sets; otherwise half-siblings.
full_sibling(X, Y) :-
    sibling(X, Y),
    setof(P, parent(P, X), Ps),
    setof(P, parent(P, Y), Ps).
half_sibling(X, Y) :- sibling(X, Y), \+ full_sibling(X, Y).

brother(X, Y) :- sibling(X, Y), male(X).
sister(X, Y)  :- sibling(X, Y), female(X).

grandparent(X, Y) :- parent(X, Z), parent(Z, Y).
grandfather(X, Y) :- grandparent(X, Y), male(X).
grandmother(X, Y) :- grandparent(X, Y), female(X).
grandchild(X, Y)  :- grandparent(Y, X).

uncle(X, Y) :- parent(Z, Y), sibling(X, Z), male(X).
aunt(X, Y)  :- parent(Z, Y), sibling(X, Z), female(X).

cousin(X, Y) :- parent(A, X), parent(B, Y), sibling(A, B), X \== Y.

ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
descendant(X, Y) :- ancestor(Y, X).

spouse(X, Y)        :- married(X, Y) ; married(Y, X).
ex_spouse_of(X, Y)  :- ex_spouse(X, Y) ; ex_spouse(Y, X).
partner(X, Y)       :- spouse(X, Y) ; ex_spouse_of(X, Y).
husband(X, Y) :- spouse(X, Y), male(X).
wife(X, Y)    :- spouse(X, Y), female(X).

parent_in_law(X, Y)  :- spouse(Y, S), parent(X, S).
child_in_law(X, Y)   :- parent_in_law(Y, X).
sibling_in_law(X, Y) :- spouse(Y, S), sibling(X, S).
sibling_in_law(X, Y) :- spouse(X, S), sibling(S, Y).

% ------------------------------------------------------------
% 2. RELATIONSHIP CALCULATOR
%    up(Person, Ancestor, N): Ancestor is N generations above Person
%    (N = 0 means Ancestor is the person themself).
% ------------------------------------------------------------
up(X, X, 0).
up(X, A, N) :- parent(P, X), up(P, A, N0), N is N0 + 1.

% Nearest common ancestor: Da / Db are the generation distances from
% X and Y; Count is how many ancestors sit at that exact distance
% (2 = through a couple = full relation, 1 = through one person = half).
closest_common(X, Y, Da, Db, Count) :-
    findall(S-Da0-Db0,
            ( up(X, A, Da0), up(Y, A, Db0), S is Da0 + Db0 ),
            L),
    L \== [],
    msort(L, [_-Da-Db|_]),
    findall(A, ( up(X, A, Da), up(Y, A, Db) ), As),
    sort(As, Unique),
    length(Unique, Count).

% relationship(X, Y, Name):  X is the <Name> of Y
relationship(X, Y, Name) :- blood_relationship(X, Y, Name), !.
relationship(X, Y, Name) :- marital_relationship(X, Y, Name), !.

blood_relationship(X, Y, Name) :-
    X \== Y,
    closest_common(X, Y, Da, Db, Count),
    name_for(Da, Db, X, Count, Name), !.

% name_for(GenerationsFromX, GenerationsFromY, X, Count, Name)
name_for(0, Db, X, _, Name) :-                 % X is an ancestor of Y
    Db >= 1,
    (   Db =:= 1
    ->  gendered(X, father, mother, Name)
    ;   N is Db - 2, greats(N, G),
        gendered(X, grandfather, grandmother, W),
        atom_concat(G, W, Name)
    ).
name_for(Da, 0, X, _, Name) :-                 % X is a descendant of Y
    Da >= 1,
    (   Da =:= 1
    ->  gendered(X, son, daughter, Name)
    ;   N is Da - 2, greats(N, G),
        gendered(X, grandson, granddaughter, W),
        atom_concat(G, W, Name)
    ).
name_for(1, 1, X, Count, Name) :-              % siblings
    gendered(X, brother, sister, W),
    (   Count >= 2 -> Name = W ; atom_concat('half-', W, Name) ).
name_for(1, Db, X, _, Name) :-                 % uncles and aunts
    Db >= 2,
    N is Db - 2, greats(N, G),
    gendered(X, uncle, aunt, W),
    atom_concat(G, W, Name).
name_for(Da, 1, X, _, Name) :-                 % nephews and nieces
    Da >= 2,
    N is Da - 2, greats(N, G),
    gendered(X, nephew, niece, W),
    atom_concat(G, W, Name).
name_for(Da, Db, _, Count, Name) :-            % cousins
    Da >= 2, Db >= 2,
    Degree is min(Da, Db) - 1,
    Removed is abs(Da - Db),
    ordinal(Degree, O),
    removed_text(Removed, R),
    (   Count >= 2 -> P = '' ; P = 'half-' ),
    format(atom(Name), '~w~w cousin~w', [P, O, R]).

gendered(X, MaleWord, FemaleWord, Word) :-
    (   male(X) -> Word = MaleWord ; Word = FemaleWord ).

greats(0, '') :- !.
greats(N, S) :- N1 is N - 1, greats(N1, S0), atom_concat('great-', S0, S).

ordinal(1, first)  :- !.
ordinal(2, second) :- !.
ordinal(3, third)  :- !.
ordinal(4, fourth) :- !.
ordinal(5, fifth)  :- !.
ordinal(N, O) :- format(atom(O), '~wth', [N]).

removed_text(0, '').
removed_text(1, ' once removed').
removed_text(2, ' twice removed').
removed_text(N, T) :- N > 2, format(atom(T), ' ~w times removed', [N]).

% Marriage-based relations (used when no blood relation exists)
marital_relationship(X, Y, Name) :-
    spouse(X, Y), gendered(X, husband, wife, Name).
marital_relationship(X, Y, Name) :-
    ex_spouse_of(X, Y), gendered(X, 'ex-husband', 'ex-wife', Name).
marital_relationship(X, Y, Name) :-
    parent_in_law(X, Y), gendered(X, 'father-in-law', 'mother-in-law', Name).
marital_relationship(X, Y, Name) :-
    child_in_law(X, Y), gendered(X, 'son-in-law', 'daughter-in-law', Name).
marital_relationship(X, Y, Name) :-
    sibling_in_law(X, Y), gendered(X, 'brother-in-law', 'sister-in-law', Name).

% ------------------------------------------------------------
% 3. EXPLANATION FACILITY
% ------------------------------------------------------------
lineage(A, A, [A]).
lineage(A, D, [A|T]) :- parent(A, C), lineage(C, D, T).

explain(X, X) :- !, format('~w and ~w are the same person.~n', [X, X]).
explain(X, Y) :-
    (   relationship(X, Y, Name)
    ->  format('~w is the ~w of ~w.~n', [X, Name, Y])
    ;   format('~w and ~w are not related in this tree.~n', [X, Y])
    ),
    (   closest_common(X, Y, Da, Db, _),
        up(X, A, Da), up(Y, A, Db),
        lineage(A, X, P1), lineage(A, Y, P2)
    ->  atomic_list_concat(P1, ' -> ', S1),
        atomic_list_concat(P2, ' -> ', S2),
        format('Nearest common ancestor: ~w~n  path to ~w: ~w~n  path to ~w: ~w~n',
               [A, X, S1, Y, S2])
    ;   true
    ).

% ------------------------------------------------------------
% 4. DATA INTEGRITY VALIDATOR
% ------------------------------------------------------------
mentioned(X) :- parent(X, _).
mentioned(X) :- parent(_, X).
mentioned(X) :- married(X, _).
mentioned(X) :- married(_, X).
mentioned(X) :- ex_spouse(X, _).
mentioned(X) :- ex_spouse(_, X).

% climbs(A, Target, Seen): walking upward from A reaches Target.
% 'Seen' makes it safe even if the data contains a loop.
climbs(A, T, Seen) :-
    parent(P, A),
    (   P == T -> true
    ;   \+ memberchk(P, Seen), climbs(P, T, [P|Seen])
    ).

has_cycle(X) :- climbs(X, X, [X]).

issue(Msg) :-
    mentioned(X), \+ person(X, _, _, _),
    format(atom(Msg), 'Missing person record: ~w', [X]).
issue(Msg) :-
    person(C, _, _, _),
    findall(P, parent(P, C), Ps0), sort(Ps0, Ps),
    length(Ps, N), N > 2,
    format(atom(Msg), '~w has ~w parents recorded (maximum is 2)', [C, N]).
issue(Msg) :-
    person(X, _, B, D), D \== alive, D < B,
    format(atom(Msg), '~w died (~w) before being born (~w)', [X, D, B]).
issue(Msg) :-
    parent(P, C), person(P, _, BP, _), person(C, _, BC, _),
    Gap is BC - BP, Gap < 15,
    format(atom(Msg),
           'Age gap between parent ~w and child ~w is ~w years (minimum 15)',
           [P, C, Gap]).
issue(Msg) :-
    parent(P, C), person(P, _, _, DP), DP \== alive,
    person(C, _, BC, _), BC > DP + 1,
    format(atom(Msg), 'Parent ~w died (~w) before child ~w was born (~w)',
           [P, DP, C, BC]).
issue(Msg) :-
    person(X, _, _, _), has_cycle(X),
    format(atom(Msg), 'Cycle detected: ~w is their own ancestor', [X]).
issue(Msg) :-
    \+ ( person(Y, _, _, _), has_cycle(Y) ),      % only safe without cycles
    married(A, B),
    closest_common(A, B, Da, Db, _),
    Da + Db =< 4,
    relationship(A, B, Rel),
    format(atom(Msg), 'Warning: spouses ~w and ~w are blood relatives (~w)',
           [A, B, Rel]).

validate :-
    findall(M, issue(M), Ms0), sort(Ms0, Ms),
    (   Ms == []
    ->  writeln('Validation passed: no inconsistencies found.')
    ;   length(Ms, N),
        format('~w issue(s) found:~n', [N]),
        forall(member(M, Ms), format('  - ~w~n', [M]))
    ).

% ------------------------------------------------------------
% 5. GENERATIONS, AGES AND STATISTICS
% ------------------------------------------------------------
% People with no recorded parents (in-laws) take the generation
% of their partner so the whole family lines up correctly.
generation(P, G) :-
    (   parent(_, P)
    ->  findall(G0, ( parent(Q, P), generation(Q, G0) ), Gs),
        max_list(Gs, M), G is M + 1
    ;   partner(P, S), parent(_, S)
    ->  generation(S, G)
    ;   G = 1
    ).

age_now(P, Age) :-
    current_year(Y), person(P, _, B, D),
    (   D == alive -> Age is Y - B ; Age is D - B ).

alive_in(P, Year) :-
    person(P, _, B, D), B =< Year,
    (   D == alive -> true ; Year =< D ).

descendants_of(P, Ds) :-
    (   setof(D, descendant(D, P), Ds) -> true ; Ds = [] ).

child_count(P, C) :- aggregate_all(count, parent(P, _), C).

family_stats :-
    aggregate_all(count, person(_, _, _, _), Total),
    aggregate_all(count, person(_, _, _, alive), Living),
    aggregate_all(max(G), ( person(P, _, _, _), generation(P, G) ), MaxGen),
    aggregate_all(min(B, Who), person(Who, _, B, alive), min(_, Oldest)),
    aggregate_all(max(C, Par), ( person(Par, _, _, _), child_count(Par, C) ),
                  max(MaxKids, Prolific)),
    format('Members recorded : ~w~n', [Total]),
    format('Currently living : ~w~n', [Living]),
    format('Generations      : ~w~n', [MaxGen]),
    format('Oldest living    : ~w~n', [Oldest]),
    format('Most children    : ~w (~w)~n', [Prolific, MaxKids]).

print_generations :-
    forall(between(1, 10, G),
           (   findall(P, ( person(P, _, _, _), generation(P, G) ), Ps0),
               sort(Ps0, Ps),
               (   Ps == [] -> true
               ;   format('Generation ~w: ~w~n', [G, Ps]) ))).

% ------------------------------------------------------------
% 6. GRAPHVIZ EXPORT   ?- export_dot('family.dot').
%    Render with:  dot -Tpng family.dot -o family.png
% ------------------------------------------------------------
export_dot(File) :-
    setup_call_cleanup(open(File, write, S), write_dot(S), close(S)),
    format('Graphviz file written: ~w~n', [File]).

write_dot(S) :-
    format(S, 'digraph Family {~n  rankdir=TB;~n  node [shape=box, style=filled];~n', []),
    forall(person(P, G, B, D),
           (   node_color(G, Color), life_label(B, D, L),
               format(S, '  ~w [label="~w\\n~w", fillcolor="~w"];~n', [P, P, L, Color]) )),
    forall(parent(P, C), format(S, '  ~w -> ~w;~n', [P, C])),
    forall(married(A, B),
           format(S, '  ~w -> ~w [dir=none, style=dashed, color=red, constraint=false];~n',
                  [A, B])),
    format(S, '}~n', []).

node_color(male, lightblue).
node_color(female, pink).

life_label(B, D, L) :-
    (   D == alive -> format(atom(L), '~w -', [B]) ; format(atom(L), '~w - ~w', [B, D]) ).

% ------------------------------------------------------------
% 7. NATURAL-LANGUAGE QUESTIONS (DCG)
%    ?- ask('Who is the aunt of aarav?').
%    ?- ask('How is arjun related to myra?').
%    ?- ask('How old is mohan?').
% ------------------------------------------------------------
ask(Text) :-
    downcase_atom(Text, Lower),
    split_string(Lower, " ", "?.!,", Parts0),
    exclude(==(""), Parts0, Parts),
    maplist(str_atom, Parts, Words),
    (   phrase(question(Goal, Template), Words)
    ->  findall(Template, Goal, L0), sort(L0, L),
        (   L == [] -> writeln('No answer found.') ; format('~w~n', [L]) )
    ;   writeln('Sorry, I did not understand that question.')
    ).

str_atom(S, A) :- atom_string(A, S).

question(call(R, X, Y), X) --> [who], be, opt_the, relword(R), [of], person_name(Y).
question(relationship(A, B, N), N) --> [how, is], person_name(A), [related, to], person_name(B).
question(age_now(P, Age), Age) --> [how, old, is], person_name(P).

be --> [is].
be --> [are].
opt_the --> [the].
opt_the --> [].
person_name(N) --> [N], { person(N, _, _, _) }.
relword(R) --> [W], { rel_alias(W, R) }.

rel_alias(father, father).           rel_alias(mother, mother).
rel_alias(parent, parent).           rel_alias(parents, parent).
rel_alias(child, child).             rel_alias(children, child).
rel_alias(son, son).                 rel_alias(sons, son).
rel_alias(daughter, daughter).       rel_alias(daughters, daughter).
rel_alias(sibling, sibling).         rel_alias(siblings, sibling).
rel_alias(brother, brother).         rel_alias(brothers, brother).
rel_alias(sister, sister).           rel_alias(sisters, sister).
rel_alias(grandfather, grandfather). rel_alias(grandmother, grandmother).
rel_alias(grandparent, grandparent). rel_alias(grandparents, grandparent).
rel_alias(grandchild, grandchild).   rel_alias(grandchildren, grandchild).
rel_alias(uncle, uncle).             rel_alias(uncles, uncle).
rel_alias(aunt, aunt).               rel_alias(aunts, aunt).
rel_alias(cousin, cousin).           rel_alias(cousins, cousin).
rel_alias(ancestor, ancestor).       rel_alias(ancestors, ancestor).
rel_alias(descendant, descendant).   rel_alias(descendants, descendant).
rel_alias(wife, wife).               rel_alias(husband, husband).
rel_alias(spouse, spouse).

% ------------------------------------------------------------
% 8. DEMO AND HELP
% ------------------------------------------------------------
show(Label, Template, Goal) :-
    findall(Template, Goal, L0), sort(L0, L),
    format('~w: ~w~n', [Label, L]).

demo :-
    writeln('--- Basic queries ---'),
    show('Children of harish   ', X, parent(harish, X)),
    show('Aunt of aarav        ', X, aunt(X, aarav)),
    show('Cousins of neha      ', X, cousin(neha, X)),
    show('Descendants of radha ', X, descendant(X, radha)),
    writeln('--- Relationship calculator ---'),
    explain(aarav, myra),
    explain(arjun, myra),
    explain(sameer, dev),
    explain(meena, radha),
    writeln('--- Natural language ---'),
    ask('Who is the aunt of aarav?'),
    ask('How is aarav related to myra?'),
    writeln('--- Statistics ---'),
    family_stats,
    print_generations,
    writeln('--- Validation ---'),
    validate.

help :-
    writeln('Commands:'),
    writeln('  demo.                     run a guided demonstration'),
    writeln('  run_tests.                run the self-test suite'),
    writeln('  relationship(X, Y, N).    X is the N of Y'),
    writeln('  explain(X, Y).            relationship plus common-ancestor paths'),
    writeln('  ask(\'Who is the aunt of aarav?\').   natural-language question'),
    writeln('  validate.                 check the data for inconsistencies'),
    writeln('  family_stats.             summary statistics'),
    writeln('  print_generations.        list members by generation'),
    writeln('  export_dot(\'family.dot\').  write a Graphviz diagram'),
    writeln('  assertz(parent(a, b)).    add a fact while running').

:- initialization(writeln('Kinship Reasoning Engine loaded. Type help. for commands.')).

% ------------------------------------------------------------
% 9. SELF-TESTS    ?- run_tests.
% ------------------------------------------------------------
test(Desc, Template, Goal, Expected) :-
    findall(Template, Goal, L0), sort(L0, L), sort(Expected, E),
    (   L == E
    ->  format('PASS: ~w~n', [Desc])
    ;   format('FAIL: ~w (got ~w, expected ~w)~n', [Desc, L, E])
    ).

check_detects(Label, Fact) :-
    assertz(Fact),
    findall(M, issue(M), Ms),
    retract(Fact),
    (   Ms \== []
    ->  format('PASS: validator detects ~w~n', [Label])
    ;   format('FAIL: validator missed ~w~n', [Label])
    ).

run_tests :-
    % basic relations
    test('children of harish',   X, parent(harish, X),       [mohan, radha, kiran]),
    test('father of dev',        X, father(X, dev),          [kiran]),
    test('mother of aarav',      X, mother(X, aarav),        [isha]),
    test('siblings of dev',      X, sibling(dev, X),         [sameer]),
    test('half-sibling of dev',  X, half_sibling(dev, X),    [sameer]),
    test('full siblings mohan',  X, full_sibling(mohan, X),  [radha, kiran]),
    test('grandparents aarav',   X, grandparent(X, aarav),   [mohan, meena]),
    test('grandchildren harish', X, grandparent(harish, X),
         [arjun, neha, rohan, pooja, sameer, dev]),
    test('aunt of aarav',        X, aunt(X, aarav),          [neha]),
    test('uncle of aarav',       X, uncle(X, aarav),         []),
    test('aunt of arjun',        X, aunt(X, arjun),          [radha]),
    test('uncle of arjun',       X, uncle(X, arjun),         [kiran]),
    test('cousins of neha',      X, cousin(neha, X),         [rohan, pooja, sameer, dev]),
    test('ancestors of aarav',   X, ancestor(X, aarav),
         [arjun, isha, mohan, meena, harish, sita]),
    test('descendants of radha', X, descendant(X, radha),    [rohan, pooja, myra]),
    % relationship calculator
    test('aarav-myra',   N, relationship(aarav, myra, N),   ['second cousin']),
    test('arjun-myra',   N, relationship(arjun, myra, N),   ['first cousin once removed']),
    test('sameer-dev',   N, relationship(sameer, dev, N),   ['half-brother']),
    test('mohan-kiran',  N, relationship(mohan, kiran, N),  [brother]),
    test('harish-aarav', N, relationship(harish, aarav, N), ['great-grandfather']),
    test('aarav-harish', N, relationship(aarav, harish, N), ['great-grandson']),
    test('radha-arjun',  N, relationship(radha, arjun, N),  [aunt]),
    test('arjun-radha',  N, relationship(arjun, radha, N),  [nephew]),
    test('meena-radha',  N, relationship(meena, radha, N),  ['sister-in-law']),
    test('harish-meena', N, relationship(harish, meena, N), ['father-in-law']),
    test('leela-kiran',  N, relationship(leela, kiran, N),  ['ex-wife']),
    test('isha-arjun',   N, relationship(isha, arjun, N),   [wife]),
    test('isha-tina',    N, relationship(isha, tina, N),    []),
    % generations and ages
    test('generation aarav', G, generation(aarav, G), [4]),
    test('generation isha',  G, generation(isha, G),  [3]),
    test('generation leela', G, generation(leela, G), [2]),
    test('age of mohan',     A, age_now(mohan, A),    [68]),
    % natural language grammar
    test('NL grammar parses a question', ok,
         phrase(question(call(aunt, _, aarav), _),
                [who, is, the, aunt, of, aarav]), [ok]),
    test('NL grammar rejects unknown person', ok,
         phrase(question(_, _), [who, is, the, aunt, of, nobody]), []),
    % validator
    test('base data is valid', M, issue(M), []),
    check_detects('a cycle',            parent(dev, harish)),
    check_detects('a missing person',   parent(ghost, dev)),
    check_detects('an impossible age gap', parent(aarav, myra)).
