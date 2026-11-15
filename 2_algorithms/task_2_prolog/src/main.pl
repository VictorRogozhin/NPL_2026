:- use_module(library(error)).
:- initialization(main, main).

kosaraju(N, Edges, Components) :-
    must_be(nonneg, N), must_be(list, Edges),
    maplist(valid_edge(N), Edges),
    (N =:= 0 -> Vertices = [] ; numlist(1, N, Vertices)),
    finish_all(Vertices, Edges, [], _, [], Order),
    maplist(reverse_edge, Edges, Transposed),
    collect_all(Order, Transposed, [], _, Raw),
    maplist(sort, Raw, Sorted), sort(Sorted, Components).

valid_edge(N, U-V) :-
    must_be(integer, U), must_be(integer, V),
    (between(1, N, U), between(1, N, V) -> true
    ; domain_error(vertex_in_range, U-V)).
reverse_edge(U-V, V-U).
neighbors(V, Edges, Next) :- findall(W, member(V-W, Edges), Next).

finish_all([], _, Seen, Seen, Order, Order).
finish_all([V|Rest], Edges, Seen0, Seen, Order0, Order) :-
    ( memberchk(V, Seen0) -> Seen1 = Seen0, Order1 = Order0
    ; neighbors(V, Edges, Next),
      finish_all(Next, Edges, [V|Seen0], Seen1, Order0, Finished),
      Order1 = [V|Finished]
    ),
    finish_all(Rest, Edges, Seen1, Seen, Order1, Order).

collect_all([], _, Seen, Seen, []).
collect_all([V|Rest], Edges, Seen0, Seen, Components) :-
    ( memberchk(V, Seen0) ->
        collect_all(Rest, Edges, Seen0, Seen, Components)
    ; visit([V], Edges, Seen0, Seen1, [], Component),
      Components = [Component|Others],
      collect_all(Rest, Edges, Seen1, Seen, Others)
    ).

visit([], _, Seen, Seen, Component, Component).
visit([V|Rest], Edges, Seen0, Seen, Acc0, Component) :-
    ( memberchk(V, Seen0) -> Seen1 = Seen0, Acc1 = Acc0
    ; neighbors(V, Edges, Next),
      visit(Next, Edges, [V|Seen0], Seen1, [V|Acc0], Acc1)
    ),
    visit(Rest, Edges, Seen1, Seen, Acc1, Component).

main :-
    catch(run, Error, (print_message(error, Error), halt(1))).
run :-
    current_prolog_flag(argv, Args),
    (Args = [Path] -> true ; Path = 'data/graph.pl'),
    setup_call_cleanup(open(Path, read, Stream),
        read_term(Stream, Term, []), close(Stream)),
    (Term = graph(N, Edges), ground(Term) -> true
    ; domain_error(graph_term, Term)),
    kosaraju(N, Edges, Components),
    format('Vertices: ~d~nEdges: ~w~n', [N, Edges]),
    length(Components, Count), format('Strongly connected components: ~d~n', [Count]),
    print_components(Components, 1).
print_components([], _).
print_components([C|Rest], I) :-
    format('Component ~d: ~w~n', [I, C]),
    Next is I + 1, print_components(Rest, Next).
