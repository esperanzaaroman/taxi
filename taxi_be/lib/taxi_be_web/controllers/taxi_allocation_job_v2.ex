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
      %{msg: "El monto total de tu viaje es de $100. Estamos buscando un taxi para ti..."}
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
  #--Handle CAsts de aceptar

  #aceptacion cuando ya alguien acepto

  def handle_cast({:process_accept, _username},%{accepted: true}= state) do
    {:noreply, state}
  end

  #primer conductor que acepta el MVP

  def handle_cast({:process_accept, username}, %{timer: timer, request: request, candidates: candidates} = state) do
    if timer != nil, do: Process.cancel_timer(timer)

    %{"username" => customer_username} = request

    Enum.each(candidates, fn candidate -> #DEBUGGING, excluyo al ganador antes de mandar el mensaje de expirado
      if candidate.nickname != username do
        TaxiBeWeb.Endpoint.broadcast(
          "driver:" <> candidate.nickname,
          "booking_expired",
          %{msg: "El viaje ya fue asignado a otro conductor"}
        )
      end
    end)

    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Tu taxi está en camino"}
    )

    taxi_asignado = %{nickname: username}
    {:noreply, state |> Map.put(:accepted, true) |> Map.put(:taxi, taxi_asignado)}
  end

  # cliente cancela antes de que alguien acepte

  # Si ya está cancelado, ignoramos cualquier intento extra
  def handle_cast({:process_cancel, _username}, %{cancelled: true} = state) do
    {:noreply, state}
  end
  
  def handle_cast({:process_cancel, username}, %{timer: timer, candidates: candidates, accepted: false} = state) do

    if timer != nil, do: Process.cancel_timer(timer)

    TaxiBeWeb.Endpoint.broadcast(
      "customer:"<> username,
      "booking_request",
      %{msg: "Cancelado antes de asignación. Cargo: $0"}
    )

    # avisar al conductor actual que ya no necesita responder
    Enum.each(candidates, fn candidate ->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> candidate.nickname,
        "booking_expired",
        %{msg: "El cliente canceló el viaje"}
      )
    end)

    {:noreply, Map.put(state, :cancelled, true)}
  end

  # Modificaciones: Cliente cancela antes de que alguien acepte (Compensación $0)
  def handle_cast({:process_cancel, _username}, %{timer: timer, candidates: candidates, accepted: false, request: request} = state) do
    if timer != nil, do: Process.cancel_timer(timer)
    %{"username" => customer_username} = request

    Enum.each(candidates, fn candidate ->
      TaxiBeWeb.Endpoint.broadcast("driver:" <> candidate.nickname, "booking_expired", %{msg: "El cliente canceló el viaje"})
    end)

    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer_username, "booking_request", %{msg: "Cancelado antes de asignación. Cargo: $0"})
    {:noreply, Map.put(state, :cancelled, true)}
  end

  # Modificaciones: Cliente cancela después de que ya alguien aceptó (Regla de los 3 minutos)
  def handle_cast({:process_cancel, username}, %{request: %{"username" => username}, taxi: taxi, accepted: true} = state) do
    # Simulamos a cuántos minutos estaba el taxi (entre 1 y 10 minutos)
    minutos_llegada = Enum.random(1..10)

    mensaje_cobro = if minutos_llegada <= 3 do
      "El taxi estaba a #{minutos_llegada} minutos. Se aplicó un cargo de $20."
    else
      "El taxi estaba a #{minutos_llegada} minutos. Sin cargo de compensación."
    end

    if taxi != nil do
      TaxiBeWeb.Endpoint.broadcast("driver:" <> taxi.nickname, "booking_cancelled", %{msg: "El cliente canceló el viaje"})
    end

    TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: mensaje_cobro})
    {:noreply, Map.put(state, :cancelled, true)}
  end


  def handle_cast({:process_cancel, username}, %{taxi: %{nickname: username}, request: request} = state) do

    %{"username" => customer_username} = request
    # Notificar al cliente que su conductor lo odia y le canceló el viaje
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Tu conductor canceló el viaje, por favor intenta de nuevo"}
    )

    {:noreply, Map.put(state, :accepted, false)}
  end

  # NUEVO: Cuando el conductor rechaza, lo sacamos de los candidatos
  def handle_cast({:process_reject, username}, %{candidates: candidates} = state) do
    # Filtramos la lista para quitar al que rechazó
    new_candidates = Enum.reject(candidates, fn c -> c.nickname == username end)

    IO.inspect("El conductor #{username} rechazó el viaje y fue eliminado de candidatos")

    {:noreply, Map.put(state, :candidates, new_candidates)}
  end

  #Manejo de timeout (me pasa mucho con rappi)
  def handle_info(:timeout, %{accepted: false, request: request}= state) do
    %{"username"=> username} = request
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> username,
      "booking_request",
      %{msg: "No fue posible encontrar un taxi para ti :( "}
    )
    {:noreply, state}
  end

  #Para ignorar los cancels.
  def handle_cast({:process_cancel, _username}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    {:noreply, state}
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
