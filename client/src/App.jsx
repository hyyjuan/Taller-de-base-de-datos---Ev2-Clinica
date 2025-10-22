import React, { useState } from 'react'; // 👈 Importamos useState
import AtencionForm from './AtencionForm';
import MorososList from './MorososList';
import PagarAtencion from './PagarAtencion';
import ProcesarMorososForm from './ProcesarMorososForm';

export default function App() {
  const [listKey, setListKey] = useState(0);

  const handleRecargaMorosos = () => {
    // Incrementa la clave para forzar la recarga
    setListKey(prevKey => prevKey + 1);
  };

  return (
    <div className="container">
      <h1>Clínica KETEKURA - Sistema de Gestión Médica</h1>

      <div style={{ display: 'flex', gap: '20px', marginBottom: '30px' }}>

        <AtencionForm /> 
        

        <PagarAtencion onProcessComplete={handleRecargaMorosos} /> 
      </div>

      <hr />

      <div style={{ display: 'flex', gap: '20px' }}>

        <ProcesarMorososForm onProcessComplete={handleRecargaMorosos} /> 


        <MorososList key={listKey} />
      </div>
    </div>
  );
}