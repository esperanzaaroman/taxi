import React, {useEffect, useState, useRef} from 'react';
import Button from '@mui/material/Button';
import socket from '../services/taxi_socket';
import { Card, CardContent, Typography } from '@mui/material';

function Driver(props) {
  let [message, setMessage] = useState("Esperando viajes...");
  let [bookingId, setBookingId] = useState();
  //Cambie a status para tener mas controlcito :PPPP
  let [status, setStatus] = useState("idle");

  const timerRef = useRef(null); // Referencia para el timer de cancelación

  // Función para matar el temporizador anterior
  const clearTimer = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
  };

  // Pone el estado, el mensaje, y a los 10 segundos regresa a "idle"
  const setTemporaryStatus = (newStatus, msg) => {
    clearTimer(); // Matamos cualquier temporizador viejo
    setStatus(newStatus);
    if (msg) setMessage(msg);

    timerRef.current = setTimeout(() => {
      setStatus("idle");
    }, 10000); 
  };

useEffect(() => {
    let channel = socket.channel("driver:" + props.username, {token: "123"});

    channel.on("booking_request", data => {
      console.log("Received", data);
      clearTimer();
      setMessage(data.msg);
      setBookingId(data.bookingId);
      setStatus("requested");
    });

    channel.on("booking_expired", data => {
      console.log("Expiró o se lo ganó otro", data);
      setTemporaryStatus("expired", data.msg);
    });

    channel.on("booking_cancelled", data => {
      console.log("CHOCARÉ PORQUE ME CANCELARON EL VIAJE", data);
      // Usamos el msg de Elixir o uno por defecto
      setTemporaryStatus("cancelled", data.msg || "El cliente canceló el viaje.");
    });

    channel.join();
    return () => clearTimer();

  }, [props.username]);

  let reply = (decision) => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: decision, username: props.username})
    }).then(resp => {
      // Si rechaza, desaparecemos la tarjeta
      if (decision === "reject") {
        setStatus("idle");
      } 
      // Si acepta, la dejamos y cambiamos el mensaje para esperar al cliente
      else if (decision === "accept") {
        setTemporaryStatus("accepted", "¡Aceptaste el viaje! Dirígete por tu cliente...");
      }
    });
  };

  const getCardColor = () => {
    if (status === "cancelled" || status === "expired") return "#d32f2f"; 
    if (status === "accepted") return "#2e7d32"; 
    return "#1976d2"; 
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid", marginBottom: "10px", borderColor: "#ccc"}}>
        {}
        <div style={{backgroundColor: "#222", color: "white", padding: "8px", fontWeight: "bold"}}>
            Driver: {props.username}
        </div>
        
        <div style={{backgroundColor: "lavender", minHeight: "140px", display: "flex", alignItems: "center", justifyContent: "center", padding: "10px"}}>
          {
            status === "idle" ? (
              <Typography color="textSecondary" style={{ fontStyle: "italic" }}>
                Sin viajes activos...
              </Typography>
            ) : (
              <Card variant="outlined" style={{
                  margin: "auto", 
                  width: "600px", 
                  borderColor: status === "cancelled" ? "#d32f2f" : "#1976d2",
                  borderWidth: "2px"
              }}>
                <CardContent>
                  <Typography color={status === "cancelled" ? "error" : "textPrimary"} variant="h6">
                    {message}
                  </Typography>
                </CardContent>
                
                {}
                {status === "requested" && (
                  <div style={{ paddingBottom: "15px", display: "flex", justifyContent: "center", gap: "15px" }}>
                    <Button onClick={() => reply("accept")} variant="contained" color="primary">Accept</Button>
                    <Button onClick={() => reply("reject")} variant="outlined" color="error">Reject</Button>
                  </div>
                )}
              </Card>
            )
          }
        </div>
    </div>
  );
}

export default Driver;
