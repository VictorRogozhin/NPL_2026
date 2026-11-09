-module(components).
-export([main/0, label/2, read_matrix/1]).

main() ->
    try
        Rows = read_matrix("data/matrix.txt"),
        {Labels, Count, Workers} = label(Rows, 3),
        io:format("Input matrix:~n"),
        print_rows(Rows),
        io:format("Processes: ~p~nComponents: ~p~nLabels:~n", [Workers, Count]),
        print_rows(Labels),
        ok = filelib:ensure_dir("results/labels.txt"),
        Text = [string:join([integer_to_list(X) || X <- Row], " ") ++ "\n"
                || Row <- Labels],
        ok = file:write_file("results/labels.txt", Text),
        io:format("Labels saved to results/labels.txt~n")
    catch Class:Reason ->
        io:format(standard_error, "Error: ~p:~p~n", [Class, Reason]),
        halt(1)
    end.

read_matrix(Path) ->
    {ok, Binary} = file:read_file(Path),
    Lines = string:split(string:trim(binary_to_list(Binary)), "\n", all),
    Rows = [[case C of $0 -> 0; $1 -> 1; _ -> error(invalid_character) end
             || C <- Line, not lists:member(C, " \t\r") ] || Line <- Lines],
    validate(Rows),
    Rows.

validate([First | _] = Rows) when First =/= [] ->
    Width = length(First),
    true = lists:all(fun(Row) -> length(Row) =:= Width andalso
                     lists:all(fun(X) -> X =:= 0 orelse X =:= 1 end, Row) end, Rows),
    ok;
validate(_) -> error(empty_matrix).

label(Rows, Requested) when is_integer(Requested), Requested > 0 ->
    validate(Rows),
    Height = length(Rows), Width = length(hd(Rows)),
    Workers = min(Requested, Height),
    Parent = self(), Ref = make_ref(),
    lists:foreach(fun(Id) ->
        Start = Height * (Id - 1) div Workers + 1,
        Stop = Height * Id div Workers,
        Stripe = lists:sublist(Rows, Start, Stop - Start + 1),
        spawn_link(fun() ->
            Local = mark_stripe(Stripe, Start, Id),
            Parent ! {Ref, Id, Local}
        end)
    end, lists:seq(1, Workers)),
    LocalLabels = gather(Workers, Ref, #{}),
    % Only vertical neighbours in different stripes can join local components.
    Pairs = [{A, maps:get({R + 1, C}, LocalLabels, A)}
             || {{R, C}, A} <- maps:to_list(LocalLabels)],
    All = lists:usort(maps:values(LocalLabels)),
    Parents = maps:from_list([{A, A} || A <- All]),
    Merged = lists:foldl(fun({A, B}, P) ->
        RA = root(A, P), RB = root(B, P),
        maps:put(RA, RB, P)
    end, Parents, Pairs),
    {Grid, _, Count} = lists:foldl(fun(R, {Out, Names, N}) ->
        {Row, NextNames, NextN} = lists:foldl(fun(C, {Acc, Ns, K}) ->
            case maps:find({R, C}, LocalLabels) of
                error -> {[0 | Acc], Ns, K};
                {ok, A} ->
                    Key = root(A, Merged),
                    case maps:find(Key, Ns) of
                        {ok, Value} -> {[Value | Acc], Ns, K};
                        error -> {[K + 1 | Acc], Ns#{Key => K + 1}, K + 1}
                    end
            end
        end, {[], Names, N}, lists:seq(1, Width)),
        {[lists:reverse(Row) | Out], NextNames, NextN}
    end, {[], #{}, 0}, lists:seq(1, Height)),
    {lists:reverse(Grid), Count, Workers}.

mark_stripe(Rows, Start, Id) ->
    Cells = maps:from_list([{{R, C}, true}
        || {R, Row} <- lists:zip(lists:seq(Start, Start + length(Rows) - 1), Rows),
           {C, 1} <- lists:zip(lists:seq(1, length(Row)), Row)]),
    {Labels, _} = lists:foldl(fun(Cell, {Acc, N}) ->
        case maps:is_key(Cell, Acc) of
            true -> {Acc, N};
            false -> {flood([Cell], Cells, {Id, N + 1}, Acc), N + 1}
        end
    end, {#{}, 0}, lists:sort(maps:keys(Cells))),
    Labels.

flood([], _, _, Labels) -> Labels;
flood([{R, C} = Cell | Rest], Cells, Tag, Labels) ->
    case maps:is_key(Cell, Cells) andalso not maps:is_key(Cell, Labels) of
        true -> flood([{R-1,C}, {R+1,C}, {R,C-1}, {R,C+1} | Rest],
                      Cells, Tag, Labels#{Cell => Tag});
        false -> flood(Rest, Cells, Tag, Labels)
    end.

gather(0, _, Labels) -> Labels;
gather(N, Ref, Labels) ->
    receive
        {Ref, _Id, Local} -> gather(N - 1, Ref, maps:merge(Labels, Local))
    after 10000 -> error(worker_timeout)
    end.

root(A, Parents) ->
    case maps:get(A, Parents) of A -> A; B -> root(B, Parents) end.

print_rows(Rows) ->
    lists:foreach(fun(Row) ->
        io:format("~s~n", [string:join([integer_to_list(X) || X <- Row], " ")])
    end, Rows).
