defmodule TaxiBeWeb.BookingController do
  use TaxiBeWeb, :controller
  alias TaxiBeWeb.TaxiAllocationJobV2
  def create(conn, req) do
    booking_id = UUID.uuid1()
    TaxiBeWeb.TaxiAllocationJobV2.start_link(
      req |> Map.put("booking_id", booking_id),
      String.to_atom(booking_id)
    )
    conn
    |> put_resp_header("Location", "/api/bookings/" <> booking_id)
    |> put_status(:created)
    |> json(%{msg: "We are processing your request", booking_id: booking_id})
  end
  def update(conn, %{"action" => "accept", "username" => username, "id" => booking_id}) do
    IO.inspect("'#{username}' is accepting a booking request")
    booking_id
    |> String.to_atom()
    |> GenServer.cast({:process_accept, username})
    json(conn, %{msg: "We will process your acceptance"})
  end

  def update(conn, %{"action" => "reject", "username" => username, "id" => booking_id}) do
    IO.inspect("'#{username}' is rejecting a booking request")
    booking_id
    |> String.to_atom()
    |> GenServer.cast({:process_reject, username})
    json(conn, %{msg: "We will process your rejection"})
  end

  def update(conn, %{"action" => "cancel", "username" => username, "id" => booking_id}) do
    IO.inspect("'#{username}' is cancelling a booking request")
    booking_id
    |> String.to_atom()
    |> GenServer.cast({:process_cancel, username})
    json(conn, %{msg: "We have cancelled your booking request"})
  end
end
