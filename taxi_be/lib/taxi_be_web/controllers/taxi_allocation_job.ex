defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, %{request: request}, name: name)
  end

  def init(state) do
    {:ok, state, {:continue, :step1}}
  end

  def handle_continue(:step1, %{request: request} = state) do
    task = Task.async(fn -> candidate_taxis() end)

    %{"username" => username} = request

    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> username,
      "booking_request",
      %{msg: "Tu viaje costará 5 pesitos"}
    )

    taxis = Task.await(task)

    {taxi, others, timer} = offer_to_next(
      state |> Map.put(:candidates, taxis |> Enum.shuffle())
    )

    {:noreply,
     state
     |> Map.put(:taxi, taxi)
     |> Map.put(:candidates, others)
     |> Map.put(:timer, timer)}
  end

  def handle_info(:timeout, state) do
    IO.puts("Boom!!")
    IO.inspect(state)
    {taxi, others, timer} = offer_to_next(state)
    {:noreply,
     state
     |> Map.put(:taxi, taxi)
     |> Map.put(:candidates, others)
     |> Map.put(:timer, timer)}
  end

  def handle_cast({:process_accept, username}, %{timer: timer} = state) do
    if timer != nil, do: Process.cancel_timer(timer)

    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> username,
      "booking_request",
      %{msg: "Tu taxi está en camino"}
    )

    {:noreply, state}
  end

  def offer_to_next(%{request: request, candidates: [taxi | others]} = _state) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request

    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_request",
      %{
        msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
        bookingId: booking_id
      }
    )

    timer = Process.send_after(self(), :timeout, 10_000)
    {taxi, others, timer}
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "pippin", latitude: 19.0061167, longitude: -98.2697737}
    ]
  end
end
