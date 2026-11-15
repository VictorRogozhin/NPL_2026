defmodule Telemetry do
  def start(port) do
    {:ok, stats} = Agent.start_link(fn -> %{} end)
    {:ok, listener} =
      :gen_tcp.listen(port, [:binary, ip: {127, 0, 0, 1}, packet: :line,
                             packet_size: 4096, active: false, reuseaddr: true])

    IO.puts("Listening on 127.0.0.1:#{port}")
    accept(listener, stats)
  end

  defp accept(listener, stats) do
    {:ok, socket} = :gen_tcp.accept(listener)
    worker = spawn(fn ->
      receive do
        {:socket, socket} ->
          try do
            serve(socket, stats)
          after
            :gen_tcp.close(socket)
          end
      end
    end)

    case :gen_tcp.controlling_process(socket, worker) do
      :ok ->
        send(worker, {:socket, socket})
      {:error, _} ->
        :gen_tcp.close(socket)
        Process.exit(worker, :shutdown)
    end
    accept(listener, stats)
  end

  defp serve(socket, stats) do
    with {:ok, line} <- :gen_tcp.recv(socket, 0),
         :ok <- :gen_tcp.send(socket, reply(line, stats) <> "\n") do
      serve(socket, stats)
    end
  end

  defp reply(line, stats) do
    with true <- String.valid?(line),
         [sensor, ts, number] <- line |> String.trim_trailing("\n")
                                     |> String.trim_trailing("\r") |> String.split(";"),
         true <- sensor != "" and not String.contains?(sensor, ["\r", "\n"]),
         {timestamp, ""} <- Integer.parse(ts),
         {value, ""} <- Float.parse(number) do
      Agent.get_and_update(stats, fn state ->
        summary = add(Map.get(state, sensor), timestamp, value)
        response = "OK;#{sensor};#{summary.count};#{summary.min};#{summary.max};" <>
                   "#{summary.mean};#{summary.latest}"
        {response, Map.put(state, sensor, summary)}
      end)
    else
      _ -> "ERR;invalid reading"
    end
  end

  defp add(nil, timestamp, value) do
    %{count: 1, min: value, max: value, mean: value, latest: timestamp}
  end

  defp add(old, timestamp, value) do
    count = old.count + 1
    # A weighted mean avoids accumulating a potentially overflowing sum.
    mean =
      if (old.mean >= 0 and value >= 0) or (old.mean <= 0 and value <= 0) do
        old.mean + (value - old.mean) / count
      else
        old.mean * (old.count / count) + value / count
      end

    %{count: count, min: min(old.min, value), max: max(old.max, value),
      mean: mean, latest: max(old.latest, timestamp)}
  end
end

port = case System.argv() do
  [] -> 4041
  [arg] -> String.to_integer(arg)
end
Telemetry.start(port)
