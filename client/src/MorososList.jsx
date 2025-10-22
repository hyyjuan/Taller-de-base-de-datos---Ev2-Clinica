import React, { useEffect, useState } from 'react';

// ELIMINAMOS O COMENTAMOS la constante API: 'http://localhost:4000'

export default function MorososList() {
  const [morosos, setMorosos] = useState([]);
  const [msg, setMsg] = useState('');

  const cargarMorosos = async () => {
    // USAMOS RUTA RELATIVA. El proxy de React añadirá 'http://localhost:4000' automáticamente.
    const res = await fetch('/api/morosos');
    const data = await res.json();
    
    if (data.ok) setMorosos(data.data);
    else setMsg(`Error cargando: ${data.error || res.statusText}`); // Mejor manejo de error
  };

  const procesarMorosos = async () => {
    setMsg('Procesando...');
    // USAMOS RUTA RELATIVA.
    const res = await fetch('/api/morosos/process', { method: 'POST' });
    const data = await res.json();
    
    if (data.ok) {
      setMsg(data.msg);
      cargarMorosos();
    } else {

      setMsg(`Error procesando: ${data.error || 'Desconocido'}`); 
    }
  };

  useEffect(() => {
    cargarMorosos();
  }, []);

  return (
    <div className="card">
      <h2>Pagos Morosos</h2>
      <button onClick={procesarMorosos}>Procesar Morosos</button>
      <p className="msg">{msg}</p>
      {morosos.length === 0 ? (
        <p>No hay morosos registrados.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID Atención</th>
              <th>Paciente</th>
              <th>Fecha Vencimiento</th>
              <th>Días Mora</th>
              <th>Multa</th>
            </tr>
          </thead>
          <tbody>
            {morosos.map((m) => (
              <tr key={m.ATE_ID}>
                <td>{m.ATE_ID}</td>
                <td>{m.PAC_NOMBRE}</td>
                <td>{new Date(m.FECHA_VENC_PAGO).toLocaleDateString()}</td>
                <td>{m.DIAS_MOROSIDAD}</td>
                <td>${m.MONTO_MULTA}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );

  
}