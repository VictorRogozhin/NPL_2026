using Sockets

mutable struct Room
    players::Vector{String}
    used::Set{String}
    last::Union{Nothing,String}
    turn::Int
    guard::ReentrantLock
end

Room() = Room(String[], Set{String}(), nothing, 1, ReentrantLock())

function join_room!(room, name)
    lock(room.guard) do
        name in room.players && return "ERR name taken"
        length(room.players) == 4 && return "ERR room full"
        push!(room.players, name)
        return "OK joined $name"
    end
end

function leave_room!(room, name)
    lock(room.guard) do
        index = findfirst(==(name), room.players)
        isnothing(index) && return
        deleteat!(room.players, index)
        room.turn -= index < room.turn ? 1 : 0
        room.turn > length(room.players) && (room.turn = 1)
        if isempty(room.players)
            empty!(room.used)
            room.last = nothing
        end
    end
end

function play!(room, name, raw_word)
    lock(room.guard) do
        length(room.players) >= 2 || return "ERR waiting for players"
        current = room.players[room.turn]
        name == current || return "ERR turn $current"
        occursin(r"\A[A-Za-z]+\z", raw_word) || return "ERR letters only"
        word = lowercase(raw_word)
        word in room.used && return "ERR already used"
        if !isnothing(room.last) && first(word) != last(room.last)
            return "ERR starts with $(last(room.last))"
        end

        push!(room.used, word)
        room.last = word
        room.turn = mod1(room.turn + 1, length(room.players))
        return "OK $word NEXT $(room.players[room.turn])"
    end
end

# The name must be chosen before this connection can submit words.
function serve(client, room)
    name = nothing
    try
        for line in eachline(client)
            words = split(line)
            reply = if length(words) != 2
                "ERR expected JOIN name or WORD word"
            elseif isnothing(name) && words[1] == "JOIN"
                candidate = String(words[2])
                status = join_room!(room, candidate)
                startswith(status, "OK ") && (name = candidate)
                status
            elseif !isnothing(name) && words[1] == "WORD"
                play!(room, name, words[2])
            else
                "ERR expected $(isnothing(name) ? "JOIN name" : "WORD word")"
            end
            println(client, reply)
            flush(client)
        end
    catch err
        err isa Base.IOError || rethrow()
    finally
        !isnothing(name) && leave_room!(room, name)
        close(client)
    end
end

function main()
    host = length(ARGS) >= 1 ? parse(IPAddr, ARGS[1]) : ip"127.0.0.1"
    port = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 4044
    room = Room()
    listener = listen(host, port)
    println("Listening on $host:$port")
    flush(stdout)
    try
        while true
            client = accept(listener)
            errormonitor(@async serve(client, room))
        end
    finally
        close(listener)
    end
end

main()
