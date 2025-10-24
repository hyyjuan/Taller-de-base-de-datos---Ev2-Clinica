/* CARLOS POBLETE - JOSEPH MUÑOZ - JUAN VARGAS */

/* PASO 1: TRIGGER */
CREATE OR REPLACE TRIGGER TRG_GENERAR_PAGO
AFTER INSERT ON ATENCION
FOR EACH ROW
DECLARE
    -- Variables para los datos del paciente
    v_sal_id            PACIENTE.sal_id%TYPE;
    v_edad              NUMBER(3);
    
    -- Variables para los descuentos
    v_porc_salud        SALUD.costo_pago%TYPE;
    v_porc_descto_edad  PORC_DESCTO_3RA_EDAD.porcentaje_descto%TYPE;
    
    -- Variables para los cálculos de montos
    v_monto_base        ATENCION.costo%TYPE;
    v_monto_a_cancelar  PAGO_ATENCION.monto_a_cancelar%TYPE;
    
    -- Variable para capturar el mensaje de error
    v_error_msg         VARCHAR2(100); 
BEGIN
    -- 1. Obtención de los datos del paciente
    -- Busca el plan de salud (sal_id) y calcula la edad en años.
    SELECT 
        sal_id,
        TRUNC(MONTHS_BETWEEN(SYSDATE, fecha_nacimiento) / 12)
    INTO 
        v_sal_id, v_edad
    FROM PACIENTE
    WHERE pac_run = :NEW.pac_run;

    -- 2. Obtención del porcentaje de cobertura del plan de salud
    BEGIN
        SELECT costo_pago -- 'costo_pago' es el % que el paciente debe pagar
        INTO v_porc_salud
        FROM SALUD
        WHERE sal_id = v_sal_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_porc_salud := 100; -- Si no tiene plan, paga el 100%
    END;
    
    -- 3. Obtención del descuento por tercera edad (si aplica)
    BEGIN
        SELECT porcentaje_descto
        INTO v_porc_descto_edad
        FROM PORC_DESCTO_3RA_EDAD
        WHERE v_edad BETWEEN anno_ini AND anno_ter;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_porc_descto_edad := 0; -- Si no está en rango, no hay descuento
    END;

    -- 4. Cálculo del monto final a pagar
    -- Aplica primero el descuento del plan de salud
    v_monto_base := :NEW.costo * (v_porc_salud / 100);
    -- Sobre ese monto, aplica el descuento por edad (si existe)
    v_monto_a_cancelar := TRUNC(v_monto_base * (1 - (v_porc_descto_edad / 100)));

    -- 5. Inserción del registro en PAGO_ATENCION
    INSERT INTO PAGO_ATENCION (
        ate_id,
        fecha_venc_pago,
        monto_atencion,     -- El costo bruto de la atención
        monto_a_cancelar,   -- El costo final con descuentos
        obs_pago
    )
    VALUES (
        :NEW.ate_id,
        :NEW.fecha_atencion + 30, -- Vencimiento en 30 días
        :NEW.costo,
        v_monto_a_cancelar,
        'PENDIENTE DE PAGO' -- Estado inicial
    );

EXCEPTION
    -- Manejo de errores (ej. si el paciente no existe)
    WHEN OTHERS THEN
        -- 1. Asigna el error (función PL/SQL) a una variable local.
        -- Se usa SUBSTR para asegurar que entre en la columna (VARCHAR2(100)).
        v_error_msg := SUBSTR('ERROR: ' || SQLERRM, 1, 100);
        
        -- 2. Inserta un registro de pago "de emergencia"
        --    para no perder la trazabilidad de la atención.
        INSERT INTO PAGO_ATENCION (
            ate_id,
            fecha_venc_pago,
            monto_atencion,
            obs_pago
        )
        VALUES (
            :NEW.ate_id,
            :NEW.fecha_atencion + 30,
            :NEW.costo,
            v_error_msg -- Guarda el error en la observación
        );
END;

/* PASO 2: ESPECIFICACION DEL PACKAGE */
CREATE OR REPLACE PACKAGE PKG_GESTION_CLINICA
IS
    /**
     * Procedimiento público para registrar una nueva atención médica.
     * Recibe los datos de la atención y los inserta.
     */
    PROCEDURE SP_INGRESAR_ATENCION(
        p_fecha_atencion DATE,
        p_hr_atencion    VARCHAR2,
        p_costo          NUMBER,
        p_med_run        NUMBER,
        p_esp_id         NUMBER,
        p_pac_run        NUMBER
    );

    /**
     * Procesa el pago de una atención existente.
     * Busca la atención por su ID y actualiza su estado a 'PAGADO'
     * y registra la fecha de pago (SYSDATE).
     */
    PROCEDURE SP_PAGAR_ATENCION(
        p_ate_id         NUMBER
    );

    /**
     * Proceso masivo que busca deudas vencidas (morosos).
     * Recorre PAGO_ATENCION, inserta los morosos en PAGO_MOROSO
     * y actualiza la observación de la factura.
     */
    PROCEDURE SP_PROCESA_PAGOS_MOROSOS(
        p_fecha_proceso  DATE
    );

    /**
     * Función que retorna el porcentaje de bonificación de un médico
     * según su cantidad de atenciones en un mes/año específico.
     * Lee la tabla TRAMO_ASIG_ATMED.
     */
    FUNCTION FN_GET_BONO_MEDICO(
        p_med_run        NUMBER,
        p_anno           NUMBER,
        p_mes            NUMBER
    ) RETURN NUMBER;
    
    /**
     * Función que retorna el porcentaje de descuento por tercera edad
     * de un paciente específico, basado en su fecha de nacimiento.
     * Lee la tabla PORC_DESCTO_3RA_EDAD.
     */
    FUNCTION FN_GET_DESCUENTO_EDAD(
        p_pac_run        NUMBER
    ) RETURN NUMBER;

    /**
     * Función que retorna el porcentaje que debe pagar el paciente
     * según su plan de salud (ej. 50%, 100%).
     * Lee la tabla SALUD.
     */
    FUNCTION FN_GET_COBERTURA_SALUD(
        p_pac_run        NUMBER
    ) RETURN NUMBER;

END PKG_GESTION_CLINICA;

/* PASO 3: CUERPO DEL PACKAGE */
CREATE OR REPLACE PACKAGE BODY PKG_GESTION_CLINICA
IS
    /**
     * Implementación de SP_INGRESAR_ATENCION
     */
    PROCEDURE SP_INGRESAR_ATENCION(
        p_fecha_atencion DATE,
        p_hr_atencion    VARCHAR2,
        p_costo          NUMBER,
        p_med_run        NUMBER,
        p_esp_id         NUMBER,
        p_pac_run        NUMBER
    )
    IS
        v_new_ate_id NUMBER;
    BEGIN
        -- 1. Obtiene el nuevo ID de atención.
        -- (Para un sistema real se usaría una SECUENCIA,
        -- pero esta lógica replica la del ejercicio de referencia).
        SELECT MAX(ate_id) + 1
        INTO v_new_ate_id
        FROM ATENCION;
        
        -- 2. Inserta el registro principal en ATENCION
        INSERT INTO ATENCION (
            ate_id,
            fecha_atencion,
            hr_atencion,
            costo,
            med_run,
            esp_id,
            pac_run
        )
        VALUES (
            v_new_ate_id,
            p_fecha_atencion,
            p_hr_atencion,
            p_costo,
            p_med_run,
            p_esp_id,
            p_pac_run
        );
        
        -- 3. El Trigger TRG_GENERAR_PAGO se disparará automáticamente
        -- después de este INSERT y creará el registro en PAGO_ATENCION.
        
    END SP_INGRESAR_ATENCION;

    /**
     * Implementación de SP_PAGAR_ATENCION
     */
    PROCEDURE SP_PAGAR_ATENCION(
        p_ate_id         NUMBER
    )
    IS
        v_count NUMBER;
    BEGIN
        -- 1. Verifica si el pago existe Y está pendiente (fecha_pago IS NULL)
        SELECT COUNT(*)
        INTO v_count
        FROM PAGO_ATENCION
        WHERE ate_id = p_ate_id AND fecha_pago IS NULL;
        
        -- 2. Solo actúa si el pago está realmente pendiente
        IF v_count > 0 THEN
            -- 3. Actualiza el pago con la fecha actual (SYSDATE)
            UPDATE PAGO_ATENCION
            SET fecha_pago = SYSDATE,
                obs_pago = 'PAGADO'
            WHERE ate_id = p_ate_id;
            
            -- 4. Si el paciente estaba en la tabla de morosos, lo limpia.
            DELETE FROM PAGO_MOROSO
            WHERE ate_id = p_ate_id;            
        END IF;        
    END SP_PAGAR_ATENCION;

    /**
     * Implementación de SP_PROCESA_PAGOS_MOROSOS
     */
    PROCEDURE SP_PROCESA_PAGOS_MOROSOS(
        p_fecha_proceso  DATE
    )
    IS
        -- Variables locales para el procesamiento
        v_dias_mora     NUMBER;
        v_multa         NUMBER;
        v_pac_nombre    PACIENTE.pnombre%TYPE;
        v_pac_apaterno  PACIENTE.apaterno%TYPE;
        v_pac_amaterno  PACIENTE.amaterno%TYPE;
        v_pac_dv        PACIENTE.dv_run%TYPE;
        v_esp_nombre    ESPECIALIDAD.nombre%TYPE;
        v_existe        NUMBER;
        
        -- 1. Define el cursor que trae todas las atenciones
        --    que estén vencidas (fecha_venc_pago < p_fecha_proceso)
        --    y que no se hayan pagado (fecha_pago IS NULL).
        CURSOR cur_morosos IS
            SELECT 
                pa.ate_id, 
                pa.fecha_venc_pago,
                pa.monto_a_cancelar,
                a.pac_run,
                a.esp_id
            FROM PAGO_ATENCION pa
            JOIN ATENCION a ON pa.ate_id = a.ate_id
            WHERE pa.fecha_pago IS NULL
            AND pa.fecha_venc_pago < p_fecha_proceso;
            
    BEGIN
        -- 2. Abre el cursor y recorre los resultados uno por uno
        FOR reg IN cur_morosos LOOP
            -- 3. Calcula los días de mora
            v_dias_mora := TRUNC(p_fecha_proceso - reg.fecha_venc_pago);
            
            IF v_dias_mora > 0 THEN
                -- 4. Obtiene los datos del paciente y la especialidad
                --    para el reporte de morosos.
                SELECT 
                    p.pnombre, p.apaterno, p.amaterno, p.dv_run, e.nombre
                INTO
                    v_pac_nombre, v_pac_apaterno, v_pac_amaterno, v_pac_dv, v_esp_nombre
                FROM PACIENTE p
                JOIN ATENCION a ON p.pac_run = a.pac_run
                JOIN ESPECIALIDAD e ON a.esp_id = e.esp_id
                WHERE a.ate_id = reg.ate_id;
                
                -- 5. Calcula la multa (Lógica de negocio: ej. 5% del monto pendiente)
                v_multa := TRUNC(reg.monto_a_cancelar * 0.05);
                
                -- 6. Revisa si el moroso ya fue ingresado en un proceso anterior
                --    (Esto es clave para evitar errores de Primary Key)
                SELECT COUNT(*) 
                INTO v_existe 
                FROM PAGO_MOROSO 
                WHERE ate_id = reg.ate_id AND pac_run = reg.pac_run;
                
                IF v_existe = 0 THEN
                    -- 7. Si es un moroso nuevo, lo inserta en PAGO_MOROSO
                    INSERT INTO PAGO_MOROSO (
                        pac_run, pac_dv_run, pac_nombre, ate_id, 
                        fecha_venc_pago, dias_morosidad, 
                        especialidad_atencion, monto_multa
                    )
                    VALUES (
                        reg.pac_run, 
                        v_pac_dv,
                        v_pac_nombre || ' ' || v_pac_apaterno || ' ' || v_pac_amaterno,
                        reg.ate_id,
                        reg.fecha_venc_pago,
                        v_dias_mora,
                        v_esp_nombre,
                        v_multa
                    );
                ELSE
                    -- 8. Si ya existía, solo actualiza los días de mora y la multa
                    UPDATE PAGO_MOROSO
                    SET dias_morosidad = v_dias_mora,
                        monto_multa = v_multa
                    WHERE ate_id = reg.ate_id AND pac_run = reg.pac_run;
                END IF;

                -- 9. Finalmente, actualiza la observación en la factura original
                UPDATE PAGO_ATENCION
                SET obs_pago = 'EN MORA - ' || v_dias_mora || ' dias'
                WHERE ate_id = reg.ate_id;
                
            END IF;
        END LOOP;
    END SP_PROCESA_PAGOS_MOROSOS;

    /**
     * Implementación de FN_GET_BONO_MEDICO
     */
    FUNCTION FN_GET_BONO_MEDICO(
        p_med_run        NUMBER,
        p_anno           NUMBER,
        p_mes            NUMBER
    ) RETURN NUMBER
    IS
        v_total_atenciones  NUMBER;
        v_porc_bono         TRAMO_ASIG_ATMED.porc_asig%TYPE;
    BEGIN
        -- 1. Cuenta las atenciones del médico para el período (año/mes)
        SELECT COUNT(*)
        INTO v_total_atenciones
        FROM ATENCION
        WHERE med_run = p_med_run
        AND TO_CHAR(fecha_atencion, 'YYYYMM') = p_anno || LPAD(p_mes, 2, '0');
        
        -- 2. Busca el tramo de bonificación en la tabla TRAMO_ASIG_ATMED
        BEGIN
            SELECT porc_asig
            INTO v_porc_bono
            FROM TRAMO_ASIG_ATMED
            WHERE v_total_atenciones BETWEEN tramo_inf_atm AND tramo_sup_atm;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_porc_bono := 0; -- Si no cae en ningún tramo, no hay bono
        END;        
        RETURN v_porc_bono;        
    END FN_GET_BONO_MEDICO;
    
    /**
     * Implementación de FN_GET_DESCUENTO_EDAD
     */
    FUNCTION FN_GET_DESCUENTO_EDAD(
        p_pac_run        NUMBER
    ) RETURN NUMBER
    IS
        v_edad            NUMBER(3);
        v_porc_descto     PORC_DESCTO_3RA_EDAD.porcentaje_descto%TYPE;
    BEGIN
        -- 1. Calcula la edad del paciente
        SELECT TRUNC(MONTHS_BETWEEN(SYSDATE, fecha_nacimiento) / 12)
        INTO v_edad
        FROM PACIENTE
        WHERE pac_run = p_pac_run;
        
        -- 2. Busca el descuento por edad en la tabla de rangos
        BEGIN
            SELECT porcentaje_descto
            INTO v_porc_descto
            FROM PORC_DESCTO_3RA_EDAD
            WHERE v_edad BETWEEN anno_ini AND anno_ter;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_porc_descto := 0; -- Si no está en rango, no hay descuento
        END;        
        RETURN v_porc_descto;        
    END FN_GET_DESCUENTO_EDAD;

    /**
     * Implementación de FN_GET_COBERTURA_SALUD
     */
    FUNCTION FN_GET_COBERTURA_SALUD(
        p_pac_run        NUMBER
    ) RETURN NUMBER
    IS
        v_sal_id          PACIENTE.sal_id%TYPE;
        v_porc_cobertura  SALUD.costo_pago%TYPE;
    BEGIN
        -- 1. Obtiene el plan de salud del paciente
        SELECT sal_id
        INTO v_sal_id
        FROM PACIENTE
        WHERE pac_run = p_pac_run;
        
        -- 2. Busca el porcentaje de cobertura (costo_pago)
        BEGIN
            SELECT costo_pago
            INTO v_porc_cobertura
            FROM SALUD
            WHERE sal_id = v_sal_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_porc_cobertura := 100; -- Asume 100% de pago si no hay plan
        END;        
        RETURN v_porc_cobertura;        
    END FN_GET_COBERTURA_SALUD;
END PKG_GESTION_CLINICA;

/* PASO 4: BLOQUE PRINCIPAL (PRUEBAS) */
SET SERVEROUTPUT ON;
-- PRUEBA A: EJECUCIÓN INICIAL (SOBRE DATOS LIMPIOS):
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- EJECUTANDO PRUEBA A: EJECUCIÓN INICIAL ---');
    -- 1. Ejecuta el proceso de morosos.
    -- (Se espera 0 resultados, ya que los datos de prueba están todos pagados)
    PKG_GESTION_CLINICA.SP_PROCESA_PAGOS_MOROSOS(SYSDATE);
    
    -- 2. Intenta pagar la atención 117.
    -- (No debería hacer nada, ya que los datos de prueba la muestran pagada)
    PKG_GESTION_CLINICA.SP_PAGAR_ATENCION(117);
    
    -- 3. Ingresa una nueva atención (ID 573).
    -- Esto disparará el Trigger TRG_GENERAR_PAGO.
    PKG_GESTION_CLINICA.SP_INGRESAR_ATENCION(
        p_fecha_atencion => TO_DATE('20/10/2025', 'DD/MM/YYYY'),
        p_hr_atencion    => '10:30',
        p_costo          => 50000,
        p_med_run        => 3126425,  -- Dra. Gregoria Gonzalez
        p_esp_id         => 900,      -- Otorrinolaringología
        p_pac_run        => 6215470   -- Paciente Nora Escobar
    );    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prueba A completada. Atención 573 creada.');
END;
/

-- PRUEBA B: SIMULACIÓN DE MOROSOS:
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- EJECUTANDO PRUEBA B: SIMULACIÓN DE MOROSOS ---');    
    -- 1. "Ensucia" los datos: Simula una factura vencida para la atención 100
    UPDATE PAGO_ATENCION
    SET 
        fecha_pago = NULL, 
        fecha_venc_pago = SYSDATE - 1,  -- Vencida ayer
        obs_pago = 'SIMULACION MOROSO'
    WHERE ate_id = 100;

    -- 2. Re-ejecuta el proceso de morosos
    PKG_GESTION_CLINICA.SP_PROCESA_PAGOS_MOROSOS(SYSDATE);    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prueba B completada. Atención 100 marcada como morosa.');
END;
/

-- PRUEBA C: SIMULACIÓN DE PAGO:
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- EJECUTANDO PRUEBA C: SIMULACIÓN DE PAGO ---');    
    -- 1. "Ensucia" los datos: Simula que la factura 117 estaba pendiente
    UPDATE PAGO_ATENCION
    SET 
        fecha_pago = NULL, 
        obs_pago = 'SIMULACION PENDIENTE'
    WHERE ate_id = 117;
    
    -- 2. Re-ejecuta el procedimiento de pago sobre la 117
    PKG_GESTION_CLINICA.SP_PAGAR_ATENCION(117);    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prueba C completada. Atención 117 marcada como PAGADA.');
END;
/

/* PASO 5: CONSULTAS */
-- 1. Verifica la nueva atención 573 (De la Prueba A)
SELECT * FROM ATENCION WHERE ate_id = 573;

-- 2. Verifica el pago creado por el Trigger para la 573 (De la Prueba A)
--    (Debe salir PENDIENTE DE PAGO y MONTO_A_CANCELAR = 25000)
SELECT * FROM PAGO_ATENCION WHERE ate_id = 573;

-- 3. Verifica la tabla de morosos (De la Prueba B)
--    (Debe aparecer la atención 100 con 1 día de mora)
SELECT * FROM PAGO_MOROSO WHERE ate_id = 100;

-- 4. Verifica el estado de la factura 100 (De la Prueba B)
--    (OBS_PAGO debe decir 'EN MORA - 1 dias')
SELECT * FROM PAGO_ATENCION WHERE ate_id = 100;

-- 5. Verifica el pago de la atención 117 (De la Prueba C)
--    (Debe salir 'PAGADO' y FECHA_PAGO debe ser la fecha de hoy)
SELECT * FROM PAGO_ATENCION WHERE ate_id = 117;