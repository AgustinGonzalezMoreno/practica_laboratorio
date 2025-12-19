-- trigger mayor de 14 años

DELIMITER //
CREATE TRIGGER cliente_edad_minima BEFORE INSERT ON Clientes
FOR EACH ROW
BEGIN
    IF TIMESTAMPDIFF(YEAR, NEW.fechaNacimiento, CURDATE()) <= 14 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente debe tener más de 14 años.';
    END IF;
END //
DELIMITER ;

-- triger mayor de 18 años y que cumpla un bool 

DELIMITER //
-- 1. CAMBIO DE PROTOCOLO
-- Le decimos a SQL: "No ejecutes nada hasta que veas las dos barras //". 
-- Es vital para empaquetar todo el código junto.

CREATE TRIGGER mayor_edad BEFORE INSERT ON lineaspedido
-- 2. EL CARTEL DE "SE BUSCA"
-- Nombre: mayor_edad
-- Momento: BEFORE (¡Alto! Identifícate antes de entrar).
-- Lugar: INSERT ON LineasPedido (Solo salta cuando intentan meter una línea nueva).

FOR EACH ROW
BEGIN
    -- 3. PREPARACIÓN DE LAS "CAJAS VACÍAS" (Variables)
    -- Como la Edad y el Permiso NO están en la tabla LineasPedido, 
    -- necesito crear variables temporales para guardar lo que averigüe fuera.
	DECLARE edadActual INT;
	DECLARE prohibidoMenores BOOLEAN;
	
	
	-- 4. INVESTIGACIÓN 1: EL PRODUCTO (Búsqueda Directa)
    -- Objetivo: Llenar la caja 'prohibidoMenores'.
	SELECT puedeVenderseAMenores INTO prohibidoMenores 
	FROM productos 
    WHERE id = NEW.productoId; 
    -- TRUCO DEL EXAMEN: 
    -- Uso "NEW.productoId" (la llave que tengo en la mano) para buscar 
    -- en la tabla Productos y sacar su norma.
	
	
	-- 5. INVESTIGACIÓN 2: EL CLIENTE (Búsqueda con Puente/JOIN)
    -- Objetivo: Llenar la caja 'edadActual'.
    -- Problema: LineasPedido no tiene la fecha. LineasPedido -> Pedidos -> Clientes.
	SELECT TIMESTAMPDIFF(YEAR, clientes.fechaNacimiento, CURDATE()) INTO edadActual
	FROM Clientes 
    INNER JOIN Pedidos ON Clientes.id = Pedidos.clienteId -- <--- EL PUENTE
	WHERE Pedidos.id = NEW.pedidoId;
    -- EXPLICACIÓN:
    -- Unimos Clientes y Pedidos pegándolos por el ID del cliente.
    -- Filtramos buscando el pedido exacto que estamos llenando (NEW.pedidoId).
    -- Calculamos la edad y la guardamos en la variable.
	
    
	-- 6. EL JUICIO FINAL (La Lógica de Negocio)
    -- Ahora miro mis dos cajas.
    -- Condición: Si el producto NO es apto para todos (FALSE) ...
    -- ... Y ADEMÁS el cliente es menor (< 18).
	IF prohibidoMenores = FALSE AND  edadActual < 18 THEN
    
        -- 7. LA SENTENCIA (El Error)
        -- Si se cumplen las condiciones malas, lanzo la alarma.
        -- 45000 es el código estándar para "Error provocado por mí".
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente debe tener al menos 18 años para comprar este producto.';
    END IF;

END //
-- 8. CIERRE DEL PAQUETE
-- Aquí acaba el bloque que SQL debe memorizar.

DELIMITER ; 
-- 9. VUELTA A LA NORMALIDAD
-- Devolvemos el control al punto y coma de siempre.





--1. El Trigger "Efecto Mariposa" (Actualización Automática de Stock)
--Situación: Tienes una tabla Productos con una columna stock. Cuando alguien compra algo (INSERT en LineasPedido), el stock debe bajar automáticamente. Dificultad: Modificar una tabla diferente a la que dispara el trigger. Tipo: AFTER INSERT (Primero confirmamos la venta, luego ajustamos el almacén).
DELIMITER //

CREATE TRIGGER actualizar_stock_venta
AFTER INSERT ON LineasPedido -- OJO: Es AFTER. Ya se ha vendido.
FOR EACH ROW
BEGIN
    -- No necesito variables, voy directo al grano.
    
    -- LÓGICA: "Actualiza la tabla Productos restando las unidades que acabo de vender"
    UPDATE Productos
    SET stock = stock - NEW.unidades -- Resto lo que entra en la línea
    WHERE id = NEW.productoId;       -- Solo al producto de esta línea
    
    -- NOTA EXAMEN: No hace falta SIGNAL SQLSTATE. 
    -- Si el stock bajara de 0 y la tabla Productos tiene un CHECK (stock >= 0),
    -- la base de datos dará error sola y cancelará todo. ¡Magia!
END //

DELIMITER ;

--2. El Trigger "Auditor" (Histórico de Precios)
--Situación: El jefe quiere saber si alguien cambia el precio de un producto. Si se cambia, hay que guardar el precio antiguo, el nuevo y la fecha en una tabla de auditoría (HistoricoPrecios). Dificultad: Usar OLD y NEW a la vez. Tipo: AFTER UPDATE (Guardamos el rastro después del cambio).
DELIMITER //

CREATE TRIGGER auditar_cambio_precio
AFTER UPDATE ON Productos
FOR EACH ROW
BEGIN
    -- LÓGICA: Solo guardamos si el precio REALMENTE ha cambiado
    -- (Si solo le cambiaron el nombre al producto, esto no salta)
    IF OLD.precioUnitario != NEW.precioUnitario THEN
        
        -- Insertamos en la tabla "chivata" (que debe existir previamente)
        INSERT INTO HistoricoPrecios (productoId, precioAntiguo, precioNuevo, fechaCambio, usuario)
        VALUES (
            OLD.id,              -- El ID del producto
            OLD.precioUnitario,  -- Cuánto valía antes
            NEW.precioUnitario,  -- Cuánto vale ahora
            NOW(),               -- Fecha y hora exacta (Función muy útil)
            USER()               -- El usuario del sistema que hizo el cambio
        );
        
    END IF;
END //

DELIMITER ;

--3. El Trigger "Tope Máximo" (Límite con COUNT)
--Situación: Regla de Negocio: "Un cliente no puede tener más de 3 pedidos 'Pendientes' de envío a la vez". Dificultad: Usar funciones de agregación (COUNT) dentro de un trigger. Tipo: BEFORE INSERT (Contamos antes de dejarle crear otro).
DELIMITER //

CREATE TRIGGER maximo_pedidos_pendientes
BEFORE INSERT ON Pedidos
FOR EACH ROW
BEGIN
    -- 1. Declaro la variable para contar
    DECLARE numeroPendientes INT;

    -- 2. Cuento cuántos tiene ya ese cliente
    SELECT COUNT(*) INTO numeroPendientes
    FROM Pedidos
    WHERE clienteId = NEW.clienteId  -- Busco sus pedidos
      AND fechaEnvio IS NULL;        -- Condición de "Pendiente" (no enviado)

    -- 3. Verifico si con el nuevo se pasa del límite (3)
    -- Si ya tiene 3 (o más), no le dejo meter el 4º.
    IF numeroPendientes >= 3 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El cliente ya tiene 3 pedidos pendientes. Espere a que se envíen.';
    END IF;

END //

DELIMITER ;

--4. El Trigger "Candado Temporal" (Inmutabilidad)
--Situación: Una vez que un pedido tiene fechaEnvio (ya ha salido del almacén), PROHIBIDO cambiar la dirección de entrega. Si intentan hacer un UPDATE a la dirección, error. Dificultad: Detectar el estado anterior (OLD) para bloquear cambios en el nuevo (NEW). Tipo: BEFORE UPDATE.
DELIMITER //

CREATE TRIGGER bloquear_cambio_direccion
BEFORE UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    -- LÓGICA COMPLEJA:
    -- 1. ¿El pedido ya estaba enviado? (OLD.fechaEnvio NO es NULL)
    -- 2. ¿Están intentando cambiar la dirección? (OLD.direccion != NEW.direccion)
    
    IF (OLD.fechaEnvio IS NOT NULL) AND (OLD.direccionEntrega != NEW.direccionEntrega) THEN
        
        -- Si ambas son verdad -> ERROR. No se toca.
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede cambiar la dirección de un pedido ya enviado.';
        
    END IF;
    
    -- Nota: Si intentan cambiar otra cosa (ej. comentarios), el trigger les dejará pasar.
END //

DELIMITER ;

