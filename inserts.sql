-- Insertamos Usuarios (Mezcla de futuros empleados y clientes)
INSERT INTO Usuarios (nombre, email, contraseña) VALUES 
('Juan Jefe', 'juan@tienda.com', 'admin1234'),      -- ID 1 (Será Empleado)
('Ana Vendedora', 'ana@tienda.com', 'ventas123'),   -- ID 2 (Será Empleado)
('Carlos Cliente', 'carlos@gmail.com', 'userpass'), -- ID 3 (Será Cliente Adulto)
('Lucía Menor', 'lucia@hotmail.com', 'niña1234');   -- ID 4 (Será Cliente Menor)

-- Insertamos Tipos de Producto
INSERT INTO TiposProducto (nombre) VALUES 
('Electrónica'), -- ID 1
('Ropa'),        -- ID 2
('Hogar'),       -- ID 3
('Bebidas');     -- ID 4

-- Insertamos Empleados (Vinculados a Usuarios 1 y 2)
INSERT INTO Empleados (UsuarioId, salario) VALUES 
(1, 2500.00), -- Juan es el jefe
(2, 1200.50); -- Ana es vendedora

-- Insertamos Clientes (Vinculados a Usuarios 3 y 4)
INSERT INTO Clientes (UsuarioId, direccionEnvio, codigoPostal, fechaNacimiento) VALUES 
(3, 'Calle Mayor 1', '28001', '1990-05-15'), -- Carlos (34 años)
(4, 'Calle Pez 2', '28002', '2010-08-20');   -- Lucía (14 años -> OJO para los triggers)

-- Insertamos Productos
INSERT INTO Productos (nombre, descripcion, precioUnitario, tipoProductoId, puedeVenderseAMenores) VALUES 
('iPhone 15', 'Smartphone último modelo', 999.99, 1, TRUE),   -- ID 1
('Camiseta SQL', 'Talla L algodón', 15.50, 2, TRUE),          -- ID 2
('Vino Reserva', 'Rioja 2018', 12.00, 4, FALSE),              -- ID 3 (PROHIBIDO MENORES)
('Sofá Cama', 'Muy cómodo', 300.00, 3, TRUE);                 -- ID 4



-- Pedido 1: De Carlos (Adulto), atendido por Ana (Emp 2). Hace 2 meses.
INSERT INTO Pedidos (clienteId, empleadoId, fechaRealizacion, fechaEnvio, direccionEntrega, comentarios) VALUES 
(1, 2, '2023-11-01', '2023-11-03', 'Calle Mayor 1', 'Entregar por la tarde');

-- Pedido 2: De Carlos (Adulto), atendido por Juan (Emp 1). Ayer (Pendiente de envío).
INSERT INTO Pedidos (clienteId, empleadoId, fechaRealizacion, fechaEnvio, direccionEntrega, comentarios) VALUES 
(1, 1, CURDATE(), NULL, 'Oficina centro', 'Urgente');

-- Pedido 3: De Lucía (Menor), SIN empleado asignado (Compra web). Hoy.
INSERT INTO Pedidos (clienteId, empleadoId, fechaRealizacion, fechaEnvio, direccionEntrega, comentarios) VALUES 
(2, NULL, CURDATE(), NULL, 'Calle Pez 2', 'Llamar antes');


-- Líneas del Pedido 1 (Carlos compró iPhone y Vino)
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario) VALUES 
(1, 1, 1, 999.99), -- iPhone
(1, 3, 2, 12.00);  -- 2 botellas de Vino

-- Líneas del Pedido 2 (Carlos compró un Sofá)
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario) VALUES 
(2, 4, 1, 300.00);

-- Líneas del Pedido 3 (Lucía compró Camiseta)
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario) VALUES 
(3, 2, 2, 15.50);


-- PRUEBA DE TRIGGER DE EDAD (Esto debería dar ERROR si lo ejecutas)
-- Intentamos vender Vino (ID 3) a Lucía (Cliente ID 2, que es menor) en el Pedido 3.

-- INSERT INTO LineasPedido (pedidoId, productoId, unidades, precioUnitario) 
-- VALUES (3, 3, 1, 12.00); 

-- Resultado esperado: Error "El cliente debe tener al menos 18 años..."