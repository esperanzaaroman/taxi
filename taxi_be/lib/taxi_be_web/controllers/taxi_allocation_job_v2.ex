defmodule TaxiBeWeb.TaxiAllocationJobV2 do
  use GenServer

  def start_link(request,name) do
    GenServer.start_link(__MODULE__,%{request: request},name: name)

  end


  def init(state) do
    {:ok,state,{:continue, :state}}
  end

  def handle_continue(:step1, %{request: request}=state) do
    %{"username"=>username}=request

    TaxiBeWeb.Endpoint.broadcast(
      "customer:"<> username,
      "booking_request",
      %{msg: "Tu viaje marianin costará 5 pesitos"}
    )

    {:noreply, state}
  end
  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "pippin", latitude: 19.0061167, longitude: -98.2697737}
    ]
  end
end
