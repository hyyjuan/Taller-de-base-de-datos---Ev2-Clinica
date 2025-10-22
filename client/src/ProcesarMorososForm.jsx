import React, { useState } from 'react';

export default function ProcesarMorososForm({ onProcessComplete }) {
  const [fechaProceso, setFechaProceso] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage('Ejecutando proceso de morosos...');

    try {
      // Usamos la ruta RELATIVA, el proxy configurado en package.json se encargará de 'http://localhost:4000'
      const res = await fetch('/api/morosos/process', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // Si fechaProceso está vacío, enviamos un objeto vacío o null, 
        // y el servidor usará la fecha actual (new Date()), como se define en tu backend.
        body: JSON.stringify({
          fecha_proceso: fechaProceso 
        })
      });

      // Manejo de errores HTTP (ej: 404, 500)
      if (!res.ok) {
          throw new Error(`Error en la solicitud: ${res.status} ${res.statusText}`);
      }

      const data = await res.json();
      
      if (data.ok) {
        setMessage(data.msg); // Mensaje de éxito del servidor
        // Si se proporciona una función de callback, la ejecutamos (ej: para recargar la lista de morosos)
        if (onProcessComplete) {
            onProcessComplete(); 
        }
      } else {
        // Error de la base de datos/lógica del servidor
        setMessage('Error al procesar: ' + data.error);
      }
      
    } catch (err) {
      // Error de red (Failed to fetch)
      setMessage('Error de conexión o inesperado: ' + err.message); 
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <h2>Procesar Pagos Morosos</h2>
      <form onSubmit={handleSubmit} className="form">
        <label htmlFor="fecha_proceso">Fecha de Proceso (Opcional):</label>
        <input 
          id="fecha_proceso"
          name="fecha_proceso" 
          type="date" 
          value={fechaProceso} 
          onChange={(e) => setFechaProceso(e.target.value)}
        />
        <button type="submit" disabled={loading}>
            {loading ? 'Procesando...' : 'Ejecutar Proceso'}
        </button>
      </form>
      <p className="msg" style={{ color: message.startsWith('Error') ? 'red' : 'green' }}>{message}</p>
    </div>
  );
}