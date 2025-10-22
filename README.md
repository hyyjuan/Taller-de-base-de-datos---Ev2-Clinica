# Taller-de-base-de-datos---Ev2-Clinica

# KETEKURA - Sistema de Gestión Médica: Documentación

Este documento sirve como `README` para el proyecto del Talle rde base de datos el Sistema de Gestión Médica de KETEKURA. El objetivo es proporcionar una herramienta para registrar atenciones y controlar la morosidad, conectando una interfaz de usuario moderna con una lógica de base de datos robusta.

***

## Estructura y Tecnologías

El proyecto sigue una arquitectura de tres capas:

| Capa | Componente | Tecnología | Propósito |
| :--- | :--- | :--- | :--- |
| **Presentación** | Cliente (`client/`) | React (con `react-scripts`) | Interfaz de usuario para la interacción con los formularios y la visualización de datos. Corre en el puerto **3000**. |
| **Lógica** | Servidor (`server.js`) | Node.js / Express | API REST que maneja la comunicación entre el cliente y la base de datos. Corre en el puerto **4000**. |
| **Datos** | Base de Datos | Oracle (mediante `oracledb`) | Almacenamiento de datos y ejecución de la lógica de negocio (Triggers y Packages). |

***

## Despliegue Local (Setup)

Para levantar el proyecto en un entorno de desarrollo local, siga los siguientes pasos, asegurándose de que **Node.js y npm** estén instalados.

### 1. Preparación de la Base de Datos

Antes de iniciar el servidor, es crucial que la lógica de negocio esté instalada en el esquema Oracle.

1.  **Ejecutar el Script SQL:** Cargar y ejecutar el script `KETEKURA_EVAl2 .sql` en la base de datos Oracle para crear el **`TRIGGER`** (`TRG_GENERAR_PAGO`) y el **`PACKAGE`** (`PKG_GESTION_CLINICA`).
2.  **Configuración de Conexión:** Asegúrese de que el archivo `server.js` tenga las credenciales y la configuración de **`Oracle Wallet`** correctas para establecer la conexión al *pool*.

### 2. Inicio del Servidor (Backend)

El servidor debe iniciarse primero para que el cliente pueda acceder a la API.

1.  **Instalar Dependencias del Servidor:**
    ```bash
    npm install
    ```
2.  **Ejecutar el Servidor:**
    ```bash
    node server.js 
    ```
    El servidor debe confirmar la conexión a la base de datos y reportar que está escuchando en **`http://localhost:4000`**.

### 3. Inicio del Cliente (Frontend)

El cliente utiliza un **Proxy** para redirigir las llamadas de `http://localhost:3000` a la API en `http://localhost:4000`.

1.  **Navegar a la Carpeta del Cliente:**
    ```bash
    cd client
    ```
2.  **Instalar Dependencias:**
    ```bash
    npm install
    ```
3.  **Verificar Configuración de Proxy:** Confirme que el archivo `client/package.json` incluye la propiedad de configuración necesaria:
    ```json
    "proxy": "http://localhost:4000",
    ```
4.  **Iniciar la Aplicación:**
    ```bash
    npm start
    ```
    La aplicación se cargará en el navegador en **`http://localhost:3000`**.

***

## Funcionalidades y Componentes

La aplicación se compone de los siguientes componentes principales, orquestados por el componente `App.jsx`.

### Componentes de Interacción

| Componente | Endpoint Utilizado | Descripción Funcional |
| :--- | :--- | :--- |
| **AtencionForm** | `POST /api/atencion` | Registra una nueva atención médica, lo que automáticamente genera un registro en `PAGO_ATENCION` vía *Trigger*. |
| **PagarAtencion** | `POST /api/pago/:ate_id/pagar` | Actualiza el estado de un pago pendiente a 'PAGADO' en la DB, utilizando el `ate_id`. |
| **ProcesarMorososForm** | `POST /api/morosos/process` | Lanza el procedimiento almacenado (`SP_PROCESA_PAGOS_MOROSOS`) para identificar y registrar atenciones vencidas. Acepta una fecha de corte opcional. |

### Componente de Visualización y Lógica Compartida

* **MorososList:** (Utiliza `GET /api/morosos`) Muestra las atenciones actualmente registradas en la tabla `PAGO_MOROSO`.
* **App.jsx:** Centraliza la **lógica de recarga** mediante el uso del estado `listKey`. Los componentes de interacción (`ProcesarMorososForm`, `PagarAtencion`) ejecutan un *callback* que actualiza esta clave, forzando a `MorososList` a re-renderizarse y recargar los datos.

***

## Debugging y Fallas Comunes

### Falla: `Failed to fetch`

Esto indica un problema de **conexión de red** entre el cliente y el servidor.

* **Causa Más Común:** El servidor Node.js no está corriendo o falló al iniciarse debido a un error de conexión con Oracle (credenciales, *wallet* incorrecta).
* **Solución:** Revisar la terminal del servidor. Si hay un error de Oracle, corregir la configuración (`server.js`) y reiniciar (`node server.js`).

### Falla: No se ven morosos después de procesar

El proceso de morosos finaliza con éxito, pero la lista está vacía.

* **Causa:** La lógica de la DB (`SP_PROCESA_PAGOS_MOROSOS`) no encontró atenciones que cumplan el criterio de morosidad (`fecha_pago IS NULL` **Y** `fecha_venc_pago < p_fecha_proceso`) en los datos de prueba.
* **Solución para Pruebas:** Utilizar el *endpoint* de prueba `POST /api/test/forzar_moroso` (si está implementado en el servidor) para marcar la factura 100 como vencida, y luego ejecutar `Procesar Morosos`.

***

(Fin del README.md)
