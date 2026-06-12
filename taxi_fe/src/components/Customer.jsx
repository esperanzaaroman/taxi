import React, {useEffect, useState} from 'react';
import Button from '@mui/material/Button'
import socket from '../services/taxi_socket';
import { TextField } from '@mui/material';

function Customer(props) {
  let [pickupAddress, setPickupAddress] = useState("Tecnologico de Monterrey, campus Puebla, Mexico");
  let [dropOffAddress, setDropOffAddress] = useState("Triangulo Las Animas, Puebla, Mexico");
  let [msg, setMsg] = useState("");
  let [msg1, setMsg1] = useState("");
  let [myBookingId, setMyBookingId] = useState(null);

  useEffect(() => {
    let channel = socket.channel("customer:" + props.username, {token: "123"});
    channel.on("greetings", data => console.log(data));
    channel.on("booking_request", dataFromPush => {
      console.log("Received", dataFromPush);
      setMsg1(dataFromPush.msg);
    });
    channel.join();
  },[props]);

  let submit = () => {
    fetch(`http://localhost:4000/api/bookings`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pickup_address: pickupAddress, dropoff_address: dropOffAddress, username: props.username})
    })
    .then(resp => resp.json())
    .then(dataFromPOST => {
      setMsg(dataFromPOST.msg);
      setMyBookingId(dataFromPOST.booking_id); 
      console.log("UUID del viaje guardado:", dataFromPOST.booking_id);
    });
  };

  let cancel = () => {

    if (!myBookingId) {
        console.warn("No hay un ID de viaje para cancelar.");
        return;
    }

    fetch(`http://localhost:4000/api/bookings/${myBookingId}`, {
      method: 'POST', 
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: 'cancel', username: props.username})
    }).then(resp => resp.json()).then(data => setMsg(data.msg));
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid", paddingBottom: "10px"}}>
      Customer: {props.username}
      <div>
          <TextField id="outlined-basic" label="Pickup address"
            fullWidth
            onChange={ev => setPickupAddress(ev.target.value)}
            value={pickupAddress}/>
          <TextField id="outlined-basic" label="Drop off address"
            fullWidth
            onChange={ev => setDropOffAddress(ev.target.value)}
            value={dropOffAddress}/>
        
        {/* ENVOLVIMOS LOS BOTONES EN UN DIV PARA QUE QUEDEN JUNTOS Y CENTRADOS */}
        <div style={{ marginTop: '15px', gap: '15px', display: 'flex', justifyContent: 'center' }}>
            <Button onClick={submit} variant="contained" color="primary">Submit</Button>
            <Button onClick={cancel} variant="outlined" color="error">Cancel</Button>
        </div>

      </div>
      <div style={{backgroundColor: "lightcyan", height: "50px", marginTop: "15px", display: "flex", alignItems: "center", justifyContent: "center"}}>
        {msg}
      </div>
      <div style={{backgroundColor: "lightblue", height: "50px", display: "flex", alignItems: "center", justifyContent: "center"}}>
        {msg1}
      </div>
    </div>
  );
}

export default Customer;