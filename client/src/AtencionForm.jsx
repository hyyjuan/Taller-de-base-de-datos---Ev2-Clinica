import React, { useState } from 'react';

// ELIMINAR: const API = 'http://localhost:4000'; 

export default function AtencionForm() {
 const [form, setForm] = useState({
     fecha_atencion: '',
     hr_atencion: '09:00',
     costo: 0,
     med_run: '',
     esp_id: '',
     pac_run: ''
 });
 const [message, setMessage] = useState('');

 const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

 const handleSubmit = async (e) => {
  e.preventDefault();
  setMessage('Enviando...');
  try {
   // CORRECCIÓN: Usar la ruta relativa /api/atencion
      const res = await fetch('/api/atencion', { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fecha_atencion: form.fecha_atencion || new Date().toISOString(),
         hr_atencion: form.hr_atencion,
          costo: Number(form.costo),
          med_run: Number(form.med_run),
          esp_id: Number(form.esp_id),
     pac_run: Number(form.pac_run)
 })
 });
      
      // Manejo de errores de red o servidor antes de intentar JSON
      if (!res.ok) {
          const errorText = await res.text();
          throw new Error(`Error ${res.status}: ${errorText}`);
      }
      
      const data = await res.json();
      setMessage(data.msg || JSON.stringify(data));
    } catch (err) {
      setMessage('Error: ' + err.message);
    }
  };

  return (
    <div className="card">
      <h2>Registrar Atención Médica</h2>
      <form onSubmit={handleSubmit} className="form">
        <label>Fecha:</label>
        <input type="date" name="fecha_atencion" value={form.fecha_atencion} onChange={handleChange} />
        <label>Hora:</label>
        <input type="time" name="hr_atencion" value={form.hr_atencion} onChange={handleChange} />
        <label>Costo:</label>
        <input type="number" name="costo" value={form.costo} onChange={handleChange} />
        <label>Médico RUN:</label>
        <input name="med_run" value={form.med_run} onChange={handleChange} />
        <label>Especialidad ID:</label>
        <input name="esp_id" value={form.esp_id} onChange={handleChange} />
        <label>Paciente RUN:</label>
        <input name="pac_run" value={form.pac_run} onChange={handleChange} />
        <button type="submit">Registrar Atención</button>
      </form>
      <p className="msg">{message}</p>
    </div>
  );
}