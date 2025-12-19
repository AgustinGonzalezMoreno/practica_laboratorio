 Solución a tu Ejercicio (Actualizar Precio)
Este ejercicio tiene tres trampas:

Validación Matemática: No bajar más del 50%.

Update con Join: Actualizar líneas de pedido filtrando por la tabla de pedidos (si no está enviado).

Transacción: Si falla el segundo update, el primero debe deshacerse.

Aquí tienes la solución comentada:

SQL

DELIMITER //

CREATE PROCEDURE actualizar_precio_producto (
    IN p_productoId INT, 
    IN p_nuevoPrecio DECIMAL(10,2)
)
BEGIN
    -- 1. Variables para guardar el precio actual
    DECLARE v_precioActual DECIMAL(10,2);

    -- 2. Manejador de errores (El "Todo o Nada")
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; -- ¡Si algo falla, vuelve atrás en el tiempo!
        RESIGNAL; -- Muestra el error por pantalla
    END;

    -- 3. Empezamos la "Grabación" de seguridad
    START TRANSACTION;

    -- PASO A: Buscamos el precio actual
    SELECT precioUnitario INTO v_precioActual
    FROM Productos
    WHERE id = p_productoId;

    -- PASO B: Validación (Regla del 50%)
    -- Si el nuevo precio es menor que la mitad del viejo... ERROR
    IF p_nuevoPrecio < (v_precioActual * 0.5) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se permite rebajar el precio más del 50%.';
    END IF;

    -- PASO C: Actualizamos el PRODUCTO (La tabla maestra)
    UPDATE Productos
    SET precioUnitario = p_nuevoPrecio
    WHERE id = p_productoId;

    -- PASO D: Actualizamos las LÍNEAS DE PEDIDO (La parte difícil)
    -- "Solo en aquellos pedidos que AÚN NO hayan sido enviados"
    -- Necesitamos cruzar LineasPedido con Pedidos para ver la fechaEnvio
    
    UPDATE LineasPedido lp
    INNER JOIN Pedidos p ON lp.pedidoId = p.id
    SET lp.precioUnitario = p_nuevoPrecio
    WHERE lp.productoId = p_productoId  -- Solo este producto
      AND p.fechaEnvio IS NULL;         -- Solo pedidos NO enviados

    -- 4. Si llegamos aquí sin errores, GUARDAMOS CAMBIOS
    COMMIT;

END //

DELIMITER ;



 Otro Ejemplo Tipo Examen: "Fusionar Pedidos"
Imagina que te piden esto: "Crear un procedimiento para mover todos los productos de un Pedido A a un Pedido B, y luego borrar el Pedido A. Solo si ambos pedidos pertenecen al mismo cliente."

Dificultad: Validar datos cruzados y mover datos de una tabla a otra.

SQL

DELIMITER //

CREATE PROCEDURE fusionar_pedidos (
    IN p_pedidoOrigen INT,
    IN p_pedidoDestino INT
)
BEGIN
    DECLARE v_clienteOrigen INT;
    DECLARE v_clienteDestino INT;

    -- El "Airbag" para transacciones
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. VALIDACIÓN: ¿Son del mismo cliente?
    SELECT clienteId INTO v_clienteOrigen FROM Pedidos WHERE id = p_pedidoOrigen;
    SELECT clienteId INTO v_clienteDestino FROM Pedidos WHERE id = p_pedidoDestino;

    IF v_clienteOrigen != v_clienteDestino THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Los pedidos pertenecen a clientes distintos.';
    END IF;

    -- 2. OPERACIÓN 1: Mover líneas de pedido
    -- Actualizamos las líneas del pedido viejo para que apunten al nuevo
    -- ¡OJO! Aquí podría haber conflictos de UNIQUE(pedidoId, productoId)
    -- En un examen simple asumimos que no chocan, o usamos IGNORE
    UPDATE LineasPedido
    SET pedidoId = p_pedidoDestino
    WHERE pedidoId = p_pedidoOrigen;

    -- 3. OPERACIÓN 2: Borrar el pedido vacío
    DELETE FROM Pedidos
    WHERE id = p_pedidoOrigen;

    COMMIT;
END //

DELIMITER ;