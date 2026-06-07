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

    {taxi, others, timer, attempts} = offer_to_next(
      state |> Map.put(:candidates, taxis |> Enum.shuffle()) |> Map.put(:attempts, 1)
    )

    {:noreply,
     state
     |> Map.put(:taxi, taxi)
     |> Map.put(:candidates, others)
     |> Map.put(:timer, timer)
     |> Map.put(:attempts, 1)}
  end

  def handle_info(:timeout, %{taxi: taxi, attempts: attempts} = state) do
    IO.puts("Boom!!")
    IO.inspect(state)

    # avisarle al conductor que ya no necesita responder
    if taxi != nil do
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_expired",
        %{msg: "La solicitud expiró"}
      )
    end

    {new_taxi, others, timer, attempts} = offer_to_next(state)
    {:noreply,
    state
    |> Map.put(:taxi, new_taxi)
    |> Map.put(:candidates, others)
    |> Map.put(:timer, timer)
    |> Map.put(:attempts, attempts)}
  end

  def handle_cast({:process_accept, _username}, %{timer: timer, request: request} = state) do
    if timer != nil, do: Process.cancel_timer(timer)

    %{"username" => customer_username} = request

    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Tu taxi está en camino"}
    )

    {:noreply, state}
  end

  def handle_cast({:process_reject, _username}, %{timer: timer, attempts: attempts} = state) do
    if timer != nil, do: Process.cancel_timer(timer)
    {taxi, others, new_timer, attempts} = offer_to_next(state)
    {:noreply,
    state
    |> Map.put(:taxi, taxi)
    |> Map.put(:candidates, others)
    |> Map.put(:timer, new_timer)
    |> Map.put(:attempts, attempts)}
  end

  # se acabaron candidatos pero aún hay intentos
  def offer_to_next(%{request: _request, candidates: [], attempts: attempts} = state) when attempts < 4 do
    new_candidates = candidate_taxis() |> Enum.shuffle()
    offer_to_next(state |> Map.put(:candidates, new_candidates) |> Map.put(:attempts, attempts + 1))
  end

  # se acabaron candidatos y ya se agotaron los intentos
  def offer_to_next(%{request: %{"username" => username}, candidates: [], attempts: attempts} = _state) do
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> username,
      "booking_request",
      %{msg: "No fue posible encontrar un taxi, intenta más tarde"}
    )
    {nil, [], nil, attempts}
  end

# hay candidatos disponibles
  def offer_to_next(%{request: request, candidates: [taxi | others], attempts: attempts} = _state) do
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
    {taxi, others, timer, attempts}
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "pippin", latitude: 19.0061167, longitude: -98.2697737}
    ]
  end
end
