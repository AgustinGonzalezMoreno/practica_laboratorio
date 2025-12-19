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

1. El Trigger "Lógico-Temporal" (Validación de fechas)
El Enunciado: "Asegura que la fecha de envío de un pedido nunca sea anterior a la fecha de realización. Un pedido no puede viajar al pasado."

¿Qué aprendes aquí? A comparar dos columnas de la misma fila (NEW contra NEW) dentro de un UPDATE.

SQL

DELIMITER //

CREATE TRIGGER validar_fechas_pedido
BEFORE UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    -- Solo comprobamos si están intentando poner una fecha de envío
    IF NEW.fechaEnvio IS NOT NULL THEN
        
        -- Si la fecha de envío es MENOR (<) que la de realización... ERROR
        IF NEW.fechaEnvio < NEW.fechaRealizacion THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La fecha de envío no puede ser anterior a la fecha de realización.';
        END IF;
        
    END IF;
END //

DELIMITER ;


2. El Trigger "Protector de Historial" (Prohibido Borrar)
El Enunciado: "No se puede eliminar una línea de pedido si el pedido ya ha sido enviado. Lo hecho, hecho está."

¿Qué aprendes aquí?

Usar BEFORE DELETE.

Usar OLD.pedidoId (porque al borrar no existe NEW, solo existe lo que había antes).

Consultar la tabla padre (Pedidos) para ver su estado.

SQL

DELIMITER //

CREATE TRIGGER proteger_lineas_enviadas
BEFORE DELETE ON LineasPedido
FOR EACH ROW
BEGIN
    DECLARE fechaEnvioPedido DATE;

    -- 1. Busco la fecha de envío del pedido al que pertenece esta línea
    -- Uso OLD.pedidoId porque es la línea que voy a borrar
    SELECT fechaEnvio INTO fechaEnvioPedido
    FROM Pedidos
    WHERE id = OLD.pedidoId;

    -- 2. Si tiene fecha (no es NULL), es que ya salió. PROHIBIDO BORRAR.
    IF fechaEnvioPedido IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se pueden borrar líneas de un pedido ya enviado.';
    END IF;

END //

DELIMITER ;



3. El Trigger "Autocompletar" (Facilitador)
El Enunciado: "Si al insertar una línea de pedido el usuario pone el precio a 0 (o no lo sabe), el sistema debe copiar automáticamente el precio actual del producto."

¿Qué aprendes aquí? A modificar el dato antes de guardarlo (SET NEW.campo = ...). Esto es súper útil y muy común en exámenes.

SQL

DELIMITER //

CREATE TRIGGER autocompletar_precio
BEFORE INSERT ON LineasPedido
FOR EACH ROW
BEGIN
    DECLARE precioReal DECIMAL(10,2);

    -- Si el usuario pone 0 o negativo, asumimos que quiere el precio oficial
    IF NEW.precioUnitario <= 0 THEN
        
        -- 1. Buscamos el precio en la tabla Productos
        SELECT precioUnitario INTO precioReal
        FROM Productos
        WHERE id = NEW.productoId;
        
        -- 2. ¡MAGIA! Cambiamos el valor que se va a guardar
        SET NEW.precioUnitario = precioReal;
        
    END IF;
END //

DELIMITER ;



4. El Trigger "Antifraude" (Validación cruzada compleja)
El Enunciado: "Un empleado no puede ser asignado a un pedido si el cliente de ese pedido es él mismo (Un empleado no puede auto-atender sus compras personales)."

¿Qué aprendes aquí? A cruzar tres tablas: Pedidos -> Empleados -> Usuarios vs Pedidos -> Clientes -> Usuarios.

SQL

DELIMITER //

CREATE TRIGGER evitar_auto_atencion
BEFORE UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    -- Solo comprobamos si hay un empleado asignado (NEW.empleadoId no es NULL)
    IF NEW.empleadoId IS NOT NULL THEN
        
        DECLARE idUsuarioDelEmpleado INT;
        DECLARE idUsuarioDelCliente INT;

        -- 1. ¿Quién es el usuario detrás del empleado?
        SELECT UsuarioId INTO idUsuarioDelEmpleado
        FROM Empleados
        WHERE id = NEW.empleadoId;

        -- 2. ¿Quién es el usuario detrás del cliente?
        SELECT UsuarioId INTO idUsuarioDelCliente
        FROM Clientes
        WHERE id = NEW.clienteId;

        -- 3. Comparación: ¿Son la misma persona?
        IF idUsuarioDelEmpleado = idUsuarioDelCliente THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Fraude: Un empleado no puede gestionar sus propios pedidos.';
        END IF;

    END IF;
END //

DELIMITER ;