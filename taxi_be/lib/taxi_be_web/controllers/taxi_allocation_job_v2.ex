defmodule TaxiBeWeb.TaxiAllocationJobV2 do
  use GenServer

  def start_link(request,name) do
    GenServer.start_link(__MODULE__,%{request: request},name: name)

  end


  def init(state) do
    {:ok, state, {:continue, :step1}}
  end

  def handle_continue(:step1, %{request: request} = state) do
    task = Task.async(fn -> candidate_taxis() end)

    %{"username"=>username}=request

    TaxiBeWeb.Endpoint.broadcast(
      "customer:"<> username,
      "booking_request",
      %{msg: "Tu viaje marianin costará 5 pesitos"}
    )

    taxis = Task.await(task)

    #Barajear los 3 taxis asi como casino

    candidates = taxis |> Enum.shuffle() |> Enum.take(3)

    #Mandar solis

    notify_all_drivers(request, candidates)

    #timer de 90 segundos

    timer = Process.send_after(self(),:timeout,90_000)


    {:noreply,
    state
    |> Map.put(:candidates, candidates)
    |> Map.put(:timer, timer)
    |> Map.put(:accepted, false)}
  end

  #para notificar a todos

  def notify_all_drivers(request, candidates) do
    %{"pickup_address" => pickup_address,
      "dropoff_address"=> dropoff_address,
      "booking_id" => booking_id
    } = request

    Enum.each(candidates, fn taxi->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:"<> taxi.nickname,
        "booking_request",
        %{
          msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'", bookingId: booking_id
        }
      )
    end)
  end
  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "pippin", latitude: 19.0061167, longitude: -98.2697737}
    ]
  end
end
