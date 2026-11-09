-module(parallel_sum).
-export([main/0, parallel_sum/2]).

main() ->
    Numbers = lists:seq(1, 100),
    Workers = 4,
    io:format("Numbers: 1..100; workers: ~p~n", [Workers]),
    Parallel = parallel_sum(Numbers, Workers),
    Sequential = lists:sum(Numbers),
    io:format("Parallel sum:   ~p~nSequential sum: ~p~n", [Parallel, Sequential]),
    case Parallel =:= Sequential of
        true -> io:format("CHECK PASSED: sums are equal~n");
        false -> erlang:error(sums_do_not_match)
    end.

parallel_sum(Numbers, Workers)
  when is_list(Numbers), is_integer(Workers), Workers > 0 ->
    Size = length(Numbers),
    case Size rem Workers of
        0 ->
            Chunks = split(Numbers, Size div Workers, Workers),
            Parent = self(),
            Ref = make_ref(),
            lists:foreach(fun({Id, Chunk}) ->
                spawn_link(fun() ->
                    Sum = lists:sum(Chunk),
                    Parent ! {Ref, Id, length(Chunk), Sum}
                end)
            end, lists:zip(lists:seq(1, Workers), Chunks)),
            collect(Workers, Ref, 0);
        _ -> erlang:error(size_must_be_divisible_by_workers)
    end.

split([], _, 0) -> [];
split(Numbers, ChunkSize, Count) ->
    {Chunk, Rest} = lists:split(ChunkSize, Numbers),
    [Chunk | split(Rest, ChunkSize, Count - 1)].

collect(0, _, Total) -> Total;
collect(Remaining, Ref, Total) ->
    receive
        {Ref, Id, Count, Sum} ->
            io:format("Worker ~p: count = ~p, sum = ~p~n", [Id, Count, Sum]),
            collect(Remaining - 1, Ref, Total + Sum)
    after 5000 ->
        erlang:error(worker_timeout)
    end.
