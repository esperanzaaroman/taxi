import React, {useEffect, useState} from 'react';
import Button from '@mui/material/Button'
import socket from '../services/taxi_socket';
import {TextField, Typography, Box, CircularProgress} from '@mui/material';

function Customer(props) {
  let [pickupAddress, setPickupAddress] = useState("Tecnologico de Monterrey, campus Puebla, Mexico");
  let [dropOffAddress, setDropOffAddress] = useState("Triangulo Las Animas, Puebla, Mexico");
  let [msg, setMsg] = useState("");
  let [msg1, setMsg1] = useState("");
  let [myBookingId, setMyBookingId] = useState(null);
  let [loading, setLoading] = useState(false);

useEffect(() => {
    let channel = socket.channel("customer:" + props.username, {token: "123"});
    channel.on("booking_request", dataFromPush => {
      setMsg1(dataFromPush.msg);
    });
    channel.join();
  },[props]);

let submit = () => {
  setLoading(true);
    fetch(`http://localhost:4000/api/bookings`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pickup_address: pickupAddress, dropoff_address: dropOffAddress, username: props.username})
    })
    .then(resp => resp.json())
    .then(dataFromPOST => {
      setMsg(dataFromPOST.msg);
      setMyBookingId(dataFromPOST.booking_id); 
      setLoading(false);
    });
  };

let cancel = () => {
    if (!myBookingId) return;
    fetch(`http://localhost:4000/api/bookings/${myBookingId}`, {
      method: 'POST', 
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: 'cancel', username: props.username})
    }).then(resp => resp.json()).then(data => setMsg(data.msg));
  };

return (
    <Box sx={{ maxWidth: 500, margin: '40px auto', fontFamily: "'Inter', sans-serif", padding: '30px' }}>
      <Typography variant="h5" sx={{ fontWeight: '600', mb: 4, color: '#111', textAlign: 'center' }}>
        Hola, {props.username}
      </Typography>

      <TextField label="Origen" fullWidth sx={{ mb: 2 }} onChange={ev => setPickupAddress(ev.target.value)} value={pickupAddress}/>
      <TextField label="Destino" fullWidth sx={{ mb: 4 }} onChange={ev => setDropOffAddress(ev.target.value)} value={dropOffAddress}/>
      
      <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2, mb: 4 }}>
          <Button disabled={loading} onClick={submit} variant="contained" sx={{ backgroundColor: '#111', borderRadius: '12px', padding: '10px 25px', '&:hover': { backgroundColor: '#333' } }}>
            {loading ? <CircularProgress size={20} color="inherit"/> : "Pedir Taxi"}
          </Button>
          <Button disabled={loading} onClick={cancel} variant="text" sx={{ color: '#ff4d4f', fontWeight: '600' }}>
            Cancelar
          </Button>
      </Box>

      <Box sx={{ borderTop: '1px solid #eee', pt: 3, textAlign: 'center' }}>
        <Typography sx={{ color: '#666', fontSize: '0.9rem' }}>{msg}</Typography>
        <Typography sx={{ fontWeight: '600', color: '#000', mt: 1 }}>{msg1}</Typography>
      </Box>
    </Box>
  );
}
export default Customer;