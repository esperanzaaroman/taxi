import React, {useEffect, useState, useRef} from 'react';
import Button from '@mui/material/Button';
import socket from '../services/taxi_socket';
import { Card, CardContent, Typography, Box } from '@mui/material';

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

      else if (decision === "cancel") {
        clearTimer();
        setStatus("idle");
      }
    });
  };

// const getColorByStatus = () => {
//     if (status === "cancelled" || status === "expired") return "#EF4444"; // Rojo estético
//     if (status === "accepted") return "#10B981"; // Verde esmeralda
//     return "#3B82F6"; // Azul moderno
//   };

return (
    <Box sx={{ 
      maxWidth: 450, 
      margin: '40px auto', 
      fontFamily: "'Inter', sans-serif", // La font bonita
      textAlign: 'center'
    }}>
        <Typography sx={{ fontSize: '0.8rem', color: '#999', letterSpacing: '2px', mb: 1, textTransform: 'uppercase' }}>
          Conductor
        </Typography>
        <Typography sx={{ fontSize: '1.5rem', fontWeight: '600', mb: 4, color: '#111' }}>
          {props.username}
        </Typography>
        
        <Box sx={{ 
            minHeight: '100px', 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            backgroundColor: '#fff',
            border: '1px solid #eee',
            borderRadius: '24px',
            padding: '30px',
            boxShadow: '0 8px 30px rgba(0,0,0,0.05)' // Sombra muy sutil
        }}>
          {status === "idle" ? (
              <Typography sx={{ color: '#888', fontWeight: '300' }}>Sin viajes activos</Typography>
            ) : (
              <Box sx={{ width: '100%' }}>
                <Typography sx={{ fontSize: '1.1rem', fontWeight: '400', color: '#333', mb: 3, lineHeight: 1.5 }}>
                  {message}
                </Typography>
                
                {status === "requested" && (
                  <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2 }}>
                    <Button onClick={() => reply("accept")} sx={{ backgroundColor: '#111', color: '#fff', borderRadius: '12px', padding: '10px 25px', '&:hover': { backgroundColor: '#333' } }}>Aceptar</Button>
                    <Button onClick={() => reply("reject")} sx={{ color: '#555', textTransform: 'none' }}>Rechazar</Button>
                  </Box>
                )}

                {status === "accepted" && (
                  <Button onClick={() => reply("cancel")} variant="text" sx={{ color: '#ff4d4f', textTransform: 'none', fontWeight: '600' }}>Cancelar viaje</Button>
                )}
              </Box>
            )
          }
        </Box>
    </Box>
  );
}

export default Driver;

