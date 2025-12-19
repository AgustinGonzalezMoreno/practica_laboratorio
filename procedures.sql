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



Ejercicio 1: "Repetir Pedido" (Clonado de Datos)
El Enunciado: "Crea un procedimiento que permita a un cliente repetir un pedido antiguo. Debe crear un NUEVO pedido con la fecha de hoy y COPIAR todas las líneas del pedido original al nuevo. Si el pedido original no existe, lanzar error."

¿Qué evalúa esto?

Tu habilidad para usar el INSERT INTO ... SELECT.

El uso de LAST_INSERT_ID() (vital para saber qué ID se generó automáticamente).

SQL

DELIMITER //

CREATE PROCEDURE repetir_pedido (
    IN p_pedidoOriginalId INT
)
BEGIN
    -- Variables para guardar datos del pedido viejo
    DECLARE v_clienteId INT;
    DECLARE v_nuevoPedidoId INT; -- Aquí guardaremos el ID del nuevo pedido

    -- 1. EL AIRBAG (Si algo falla, deshacer todo)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- PASO A: Validar que el pedido original existe y coger su cliente
    SELECT clienteId INTO v_clienteId
    FROM Pedidos
    WHERE id = p_pedidoOriginalId;

    -- Si v_clienteId es NULL, es que el pedido no existía
    IF v_clienteId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido original no existe.';
    END IF;

    -- PASO B: Crear la CABECERA del nuevo pedido
    -- (Insertamos copiando datos del viejo, pero poniendo fecha de HOY y sin fecha de envío)
    INSERT INTO Pedidos (clienteId, empleadoId, fechaRealizacion, fechaEnvio, direccionEntrega, comentarios)
    SELECT clienteId, empleadoId, CURDATE(), NULL, direccionEntrega, 'Pedido Repetido'
    FROM Pedidos
    WHERE id = p_pedidoOriginalId;

    -- PASO C: ¡TRUCO DE EXAMEN! ¿Cuál es el ID del pedido que acabo de crear?
    -- La función LAST_INSERT_ID() te devuelve el último AUTO_INCREMENT generado.
    SET v_nuevoPedidoId = LAST_INSERT_ID();

    -- PASO D: Copiar las LÍNEAS (Detalles)
    -- Insertamos en LineasPedido buscando las del viejo y cambiándoles el pedidoId
    INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario)
    SELECT v_nuevoPedidoId, productoId, unidades, precioUnitario
    FROM LineasPedido
    WHERE pedidoId = p_pedidoOriginalId;

    COMMIT; -- Todo ha salido bien
END //

DELIMITER ;
Ejercicio 2: "Ruta de Reparto" (Actualización Masiva)
El Enunciado: "Crea un procedimiento que marque como ENVIADOS (fechaEnvio = HOY) todos los pedidos pendientes de una zona concreta (código postal). El procedimiento debe devolverte (OUT) el número de pedidos que se han actualizado. Si no había ninguno pendiente en esa zona, lanzar un error."

¿Qué evalúa esto?

Uso de parámetros de SALIDA (OUT).

Actualizar una tabla (Pedidos) filtrando por otra (Clientes).

Uso de ROW_COUNT() para saber a cuántas filas afectó tu operación.

SQL

DELIMITER //

CREATE PROCEDURE enviar_zona_reparto (
    IN p_codigoPostal VARCHAR(10), -- Entrada: Qué zona repartimos
    OUT p_totalActualizados INT    -- Salida: Cuántos hemos actualizado
)
BEGIN
    -- 1. EL AIRBAG
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- PASO A: Actualización Masiva con JOIN
    -- "Pon fecha de hoy a los pedidos cuyo cliente tenga el CP indicado"
    UPDATE Pedidos p
    JOIN Clientes c ON p.clienteId = c.id
    SET p.fechaEnvio = CURDATE()
    WHERE c.codigoPostal = p_codigoPostal -- Filtro por zona del cliente
      AND p.fechaEnvio IS NULL;           -- Solo los que estaban pendientes

    -- PASO B: Contar qué ha pasado
    -- ROW_COUNT() es una función del sistema que dice: 
    -- "¿A cuántas filas afectó el último UPDATE/DELETE/INSERT?"
    SET p_totalActualizados = ROW_COUNT();

    -- PASO C: Validación posterior
    IF p_totalActualizados = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'No había pedidos pendientes en este Código Postal.';
    END IF;

    COMMIT;
END //

DELIMITER ;



3. Solución Procedimiento: Crear Producto y Regalo Automático
Conceptos clave que evalúa:

LAST_INSERT_ID(): Cuando creas el producto, necesitas saber qué ID le ha dado la base de datos para poder meterlo luego en el pedido.

Lógica Condicional: Crear el pedido SOLO si es para regalo.

Búsqueda del "Más Antiguo": Usar ORDER BY id ASC LIMIT 1.

SQL

DELIMITER //

CREATE PROCEDURE crear_producto_regalo (
    -- Parámetros del nuevo producto
    IN p_nombre VARCHAR(250),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10, 2),
    IN p_tipoId INT,
    IN p_paraMenores BOOLEAN,
    -- Parámetro "Interruptor" (¿Es regalo?)
    IN p_esParaRegalo BOOLEAN
)
BEGIN
    -- VARIABLES
    DECLARE v_nuevoProductoId INT; -- Para guardar el ID del producto creado
    DECLARE v_clienteAntiguoId INT; -- Para guardar el ID del cliente afortunado
    DECLARE v_nuevoPedidoId INT;    -- Para guardar el ID del pedido de regalo

    -- 1. EL AIRBAG (Transacción segura)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- PASO A: Validación de Precio (Regla de Negocio)
    -- Si es para regalo (TRUE) Y vale más de 50... ERROR.
    IF p_esParaRegalo = TRUE AND p_precio > 50 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se permite crear un producto para regalo de más de 50€.';
    END IF;

    -- PASO B: Crear el Producto (Esto se hace SIEMPRE)
    INSERT INTO Productos (nombre, descripcion, precioUnitario, tipoProductoId, puedeVenderseAMenores)
    VALUES (p_nombre, p_descripcion, p_precio, p_tipoId, p_paraMenores);

    -- ¡CRUCIAL! Capturamos el ID que acaba de nacer
    SET v_nuevoProductoId = LAST_INSERT_ID();

    -- PASO C: La Lógica del Regalo (Solo si p_esParaRegalo es TRUE)
    IF p_esParaRegalo = TRUE THEN

        -- 1. Buscamos al cliente más antiguo (El que tiene el ID más bajo)
        SELECT id INTO v_clienteAntiguoId
        FROM Clientes
        ORDER BY id ASC -- De menor a mayor
        LIMIT 1;        -- Solo quiero el primero

        -- 2. Creamos un PEDIDO para ese cliente (Cabecera)
        INSERT INTO Pedidos (clienteId, fechaRealizacion, direccionEntrega, comentarios)
        VALUES (v_clienteAntiguoId, CURDATE(), 'Dirección Cliente', 'Regalo Promocional');

        -- ¡CRUCIAL! Capturamos el ID del pedido nuevo
        SET v_nuevoPedidoId = LAST_INSERT_ID();

        -- 3. Creamos la LÍNEA DE PEDIDO (Detalle)
        -- OJO: El enunciado dice "costes 0€".
        INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario)
        VALUES (v_nuevoPedidoId, v_nuevoProductoId, 1, 0.00);

    END IF;

    -- Si llegamos aquí, todo ha ido bien. Guardamos.
    COMMIT;

END //

DELIMITER ;



Tema: Archivar y Borrar (Backup)

Enunciado: "Crea un procedimiento para dar de baja a un empleado. Antes de borrarlo de la tabla Empleados, debe guardar sus datos (nombre y salario total ganado en su historia) en una tabla llamada ExEmpleados. Si el empleado tiene pedidos asignados activos (sin enviar), no se permite borrarlo."

Dificultad: INSERT INTO ... SELECT + Validación de Dependencias (FOREIGN KEY lógica).

SQL

DELIMITER //

CREATE PROCEDURE despedir_empleado (
    IN p_empleadoId INT
)
BEGIN
    DECLARE v_tienePendientes INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. VALIDACIÓN: ¿Tiene pedidos sin enviar?
    SELECT COUNT(*) INTO v_tienePendientes
    FROM Pedidos
    WHERE empleadoId = p_empleadoId AND fechaEnvio IS NULL;

    IF v_tienePendientes > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede despedir a un empleado con pedidos pendientes.';
    END IF;

    -- 2. ARCHIVAR: Copiar datos a la tabla histórica
    -- Suponemos que la tabla ExEmpleados ya existe (id, nombre, totalVendido, fechaDespido)
    INSERT INTO ExEmpleados (nombre, totalVendido, fechaDespido)
    SELECT 
        u.nombre, 
        (SELECT SUM(lp.unidades * lp.precioUnitario) 
         FROM Pedidos p JOIN LineasPedido lp ON p.id = lp.pedidoId 
         WHERE p.empleadoId = p_empleadoId), -- Subconsulta para calcular ventas
        CURDATE()
    FROM Empleados e
    JOIN Usuarios u ON e.usuarioId = u.id
    WHERE e.id = p_empleadoId;

    -- 3. BORRAR: Eliminar de la tabla original
    DELETE FROM Empleados WHERE id = p_empleadoId;

    COMMIT;
END //

DELIMITER ;