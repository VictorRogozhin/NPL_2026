port = case System.argv() do
  [] -> 4041
  [arg] -> String.to_integer(arg)
end

demo = fn readings ->
  {:ok, socket} =
    :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, packet: :line, active: false], 5000)
  try do
    Enum.map(readings, fn line ->
      :ok = :gen_tcp.send(socket, line <> "\n")
      {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
      "#{line} => #{String.trim_trailing(response)}"
    end)
  after
    :gen_tcp.close(socket)
  end
end

tasks = [
  Task.async(fn -> demo.(["room;1700000000;20.0", "room;1700000001;24.0", "room;bad;10"]) end),
  Task.async(fn -> demo.(["outside;1700000000;8.0", "outside;1700000001;12.0"]) end)
]
Enum.each(tasks, fn task -> Enum.each(Task.await(task, 10_000), &IO.puts/1) end)
