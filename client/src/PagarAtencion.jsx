import React, { useState } from 'react';

export default function PagarAtencion() {
  const [ateId, setAteId] = useState('');
  const [message, setMessage] = useState('');

  const handleChange = (e) => {
    // Aseguramos que solo se acepten números si es necesario
    setAteId(e.target.value.replace(/\D/, '')); 
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('Procesando pago...');

    const id = Number(ateId);
    
    if (!id || id <= 0) {
        setMessage('Error: ID de Atención inválido.');
        return;
    }

    try {

      const url = `/api/pago/${id}/pagar`; 
      
      const res = await fetch(url, {
        method: 'POST',

        headers: { 'Content-Type': 'application/json' }, 

      });

      // Manejo de errores HTTP
      if (!res.ok) {
          throw new Error(`Error en la solicitud: ${res.status} ${res.statusText}`);
      }

      const data = await res.json();
      
      if (data.ok) {
        setMessage(data.msg); 
        setAteId(''); // Limpiar el campo tras el éxito
      } else {
        setMessage('Error en el servidor: ' + data.error);
      }
      
    } catch (err) {
      // Manejo de errores de red (Failed to fetch) o errores lanzados
      setMessage('Error de conexión: ' + err.message); 
    }
  };

  return (
    <div className="card">
      <h2>Registrar Pago de Atención</h2>
      <form onSubmit={handleSubmit} className="form">
        <label htmlFor="ate_id">ID de Atención a Pagar:</label>
        <input 
          id="ate_id"
          name="ate_id" 
          type="number" 
          value={ateId} 
          onChange={handleChange}
          placeholder="Ej: 101"
          required
        />
        <button type="submit">Pagar Atención</button>
      </form>
      <p className="msg">{message}</p>
    </div>
  );
}