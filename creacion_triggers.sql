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