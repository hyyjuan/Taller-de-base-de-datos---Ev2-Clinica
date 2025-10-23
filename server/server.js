require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const oracledb = require('oracledb');

const app = express();
app.use(bodyParser.json());

process.env.TNS_ADMIN = process.env.DB_WALLET_DIR;

try {
  if (typeof oracledb === 'undefined') {
    console.log('Oracle DB client no encontrado, instalando...');
    require('oracledb').initOracleClient();
  } else {
    console.log('Oracle DB client ya está inicializado.');
  }
} catch (e) {
  console.log('Error al inicializar el cliente Oracle: ', e);
}

const poolConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  connectString: process.env.DB_TNS,
  walletLocation: process.env.DB_WALLET_DIR,
  walletPassword: process.env.DB_WALLET_PASS,
  externalAuth: false,
  poolMin: 1,
  poolMax: 5,
  poolIncrement: 1
};

async function start() {
  try {
    await oracledb.createPool(poolConfig);
    console.log(' Conectado a Oracle Autonomous con wallet.');
  } catch (err) {
    console.error(' Error creando pool Oracle:', err);
    process.exit(1);
  }

  // Prueba de conexión
  app.get('/api/test', async (req, res) => {
    let conn;
    try {
      conn = await oracledb.getConnection();
      const result = await conn.execute('SELECT sysdate FROM dual');
      res.json({ ok: true, fecha: result.rows[0][0] });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    } finally {
      if (conn) await conn.close();
    }
  });

  // Registrar atención médica
  app.post('/api/atencion', async (req, res) => {
    const { fecha_atencion, hr_atencion, costo, med_run, esp_id, pac_run } = req.body;
    let conn;
    try {
      conn = await oracledb.getConnection();
      const plsql = `
        BEGIN
          PKG_GESTION_CLINICA.SP_INGRESAR_ATENCION(
            p_fecha_atencion => :p_fecha_atencion,
            p_hr_atencion    => :p_hr_atencion,
            p_costo          => :p_costo,
            p_med_run        => :p_med_run,
            p_esp_id         => :p_esp_id,
            p_pac_run        => :p_pac_run
          );
        END;`;
      await conn.execute(plsql, {
        p_fecha_atencion: { val: new Date(fecha_atencion), type: oracledb.DATE },
        p_hr_atencion: { val: hr_atencion, type: oracledb.STRING },
        p_costo: { val: costo, type: oracledb.NUMBER },
        p_med_run: { val: med_run, type: oracledb.NUMBER },
        p_esp_id: { val: esp_id, type: oracledb.NUMBER },
        p_pac_run: { val: pac_run, type: oracledb.NUMBER },
      }, { autoCommit: true });
      res.json({ ok: true, msg: 'Atención ingresada correctamente.' });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    } finally {
      if (conn) await conn.close();
    }
  });

  // Pagar atención
  app.post('/api/pago/:ate_id/pagar', async (req, res) => {
    const ate_id = Number(req.params.ate_id);
    let conn;
    try {
      conn = await oracledb.getConnection();
      await conn.execute(
        `BEGIN PKG_GESTION_CLINICA.SP_PAGAR_ATENCION(p_ate_id => :p_ate_id); END;`,
        { p_ate_id: ate_id },
        { autoCommit: true }
      );
      res.json({ ok: true, msg: `Pago registrado para atención ${ate_id}.` });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    } finally {
      if (conn) await conn.close();
    }
  });

  // Procesar morosos
  app.post('/api/morosos/process', async (req, res) => {
    const fecha = req.body.fecha_proceso ? new Date(req.body.fecha_proceso) : new Date();
    let conn;
    try {
      conn = await oracledb.getConnection();
      await conn.execute(
        `BEGIN PKG_GESTION_CLINICA.SP_PROCESA_PAGOS_MOROSOS(p_fecha_proceso => :p_fecha_proceso); END;`,
        { p_fecha_proceso: { val: fecha, type: oracledb.DATE } },
        { autoCommit: true }
      );
      res.json({ ok: true, msg: 'Proceso de morosos ejecutado correctamente.' });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    } finally {
      if (conn) await conn.close();
    }
  });

  // Listar morosos
  app.get('/api/morosos', async (req, res) => {
    let conn;
    try {
      conn = await oracledb.getConnection();
      const result = await conn.execute(
        `SELECT * FROM PAGO_MOROSO ORDER BY fecha_venc_pago DESC`,
        {},
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      res.json({ ok: true, data: result.rows });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    } finally {
      if (conn) await conn.close();
    }
  });

  const port = process.env.PORT || 4000;
  app.listen(port, () => console.log(`🚀 Servidor en http://localhost:${port}`));
}

start();
