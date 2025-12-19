1. El Clásico "Informe de 3 Niveles" (JOIN Múltiple)
Objetivo: "Listar el nombre del cliente, el nombre del empleado que le atendió y la fecha del pedido."

¿Qué evalúan? Tu capacidad para saltar de tabla en tabla.

Camino: Clientes -> Pedidos -> Empleados.


SELECT 
    u_cli.nombre AS NombreCliente, -- Saco nombre del Usuario (que es el cliente)
    u_emp.nombre AS NombreEmpleado, -- Saco nombre del Usuario (que es el empleado)
    p.fechaRealizacion
FROM Pedidos p
-- 1. Unimos el Pedido con el Cliente, y luego con su Usuario para sacar el nombre
JOIN Clientes c ON p.clienteId = c.id
JOIN Usuarios u_cli ON c.usuarioId = u_cli.id
-- 2. Unimos el Pedido con el Empleado, y luego con su Usuario
JOIN Empleados e ON p.empleadoId = e.id
JOIN Usuarios u_emp ON e.usuarioId = u_emp.id;
--Nota de examen: Fíjate que he tenido que unir con la tabla Usuarios dos veces (una para el cliente, otra para el empleado). Por eso uso ALIAS distintos (u_cli y u_emp). Si no pones alias, SQL no sabe a qué "tabla Usuarios" te refieres.

2. La "Matemática Oculta" (Cálculos + Agregación)
Objetivo: "Dime cuánto dinero se ha gastado cada cliente en total en la historia de la tienda."

¿Qué evalúan?

Saber que el "dinero gastado" no es una columna, sino unidades * precio.

Saber agrupar (GROUP BY) por cliente.



SELECT 
    u.nombre, 
    SUM(lp.unidades * lp.precioUnitario) AS TotalGastado
FROM Usuarios u
JOIN Clientes c ON u.id = c.usuarioId
JOIN Pedidos p ON c.id = p.clienteId
JOIN LineasPedido lp ON p.id = lp.pedidoId
GROUP BY u.id, u.nombre; -- Agrupamos por ID (que es único) y Nombre
Nota de examen: Si te piden "Total por cliente", el GROUP BY es obligatorio. Sin él, solo te saldría un número gigante (la suma de toda la tienda)



3. El Filtro Post-Agregación (HAVING)
Objetivo: "Dime qué productos se han vendido MÁS de 50 veces en total."

¿Qué evalúan? La diferencia entre WHERE y HAVING.

WHERE: Filtra filas antes de agrupar (ej: "Solo ventas de ayer").

HAVING: Filtra grupos después de hacer la matemática (ej: "Solo sumas mayores a 50").


SELECT 
    prod.nombre, 
    SUM(lp.unidades) AS TotalUnidadesVendidas
FROM Productos prod
JOIN LineasPedido lp ON prod.id = lp.productoId
GROUP BY prod.id, prod.nombre
HAVING SUM(lp.unidades) > 50; -- <--- LA CLAVE ES ESTA
Trampa típica: Si pones WHERE SUM(unidades) > 50, te dará error. El WHERE no sabe sumar, solo mira fila por fila. Para totales, usa HAVING.


4. El "Detective de los Solteros" (LEFT JOIN + IS NULL)
Objetivo: "Dime qué empleados NUNCA han gestionado ningún pedido."

¿Qué evalúan? Saber encontrar datos que NO tienen relación.

Si usas INNER JOIN (el normal), solo salen los empleados que trabajan.

Para ver a los que no trabajan, necesitas LEFT JOIN y buscar los huecos vacíos (NULL).

SELECT u.nombre
FROM Empleados e
JOIN Usuarios u ON e.usuarioId = u.id -- Join normal para saber su nombre
LEFT JOIN Pedidos p ON e.id = p.empleadoId -- <--- LEFT JOIN (Trae a TODOS los empleados)
WHERE p.id IS NULL; -- <--- LA CONDICIÓN (Quédate con los que no tienen pedido asociado)
Nota de examen: Siempre que leas "Listar los X que NO han hecho Y", piensa automáticamente en LEFT JOIN ... WHERE ... IS NULL.

5. La Subconsulta Comparativa (Nivel Alto)
Objetivo: "Muestra los productos que son más caros que el precio medio de todos los productos."

¿Qué evalúan? Capacidad de anidar preguntas.

Pregunta interna: ¿Cuál es el precio medio?

Pregunta externa: ¿Quién supera ese número?


SELECT nombre, precioUnitario
FROM Productos
WHERE precioUnitario > (
    SELECT AVG(precioUnitario) FROM Productos -- Esto se calcula primero (ej: devuelve 25.50)
);
Nota de examen: Fíjate que la subconsulta va entre paréntesis. Es como si dijeras WHERE precio > 25.50, pero de forma dinámica.



1. El "Ranking de Oro" (Top N con Facturación)
Objetivo: "Obtén los 3 clientes que más dinero han gastado en toda la historia de la tienda, mostrando su nombre y el total gastado."

¿Qué evalúa?

Calcular un dato que no existe (precio * unidades).

Agrupar por cliente.

Ordenar y cortar la lista (LIMIT).

SQL

SELECT 
    u.nombre, 
    SUM(lp.unidades * lp.precioUnitario) AS TotalGastado
FROM Usuarios u
JOIN Clientes c ON u.id = c.usuarioId
JOIN Pedidos p ON c.id = p.clienteId
JOIN LineasPedido lp ON p.id = lp.pedidoId
GROUP BY u.id, u.nombre -- Agrupamos por la persona
ORDER BY TotalGastado DESC -- Ordenamos del más rico al más pobre
LIMIT 3; -- Cortamos para quedarnos con el podio


2. La Comparación Global (Subconsulta en HAVING)
Objetivo: "Muestra los empleados que han gestionado más pedidos que el promedio de pedidos gestionados por empleado."

¿Qué evalúa? Esta es difícil. Tienes que comparar a un individuo contra el grupo.

Primero calculas cuántos pedidos lleva cada empleado.

Luego filtras (HAVING) comparando con una subconsulta que calcula la media.

SQL

SELECT 
    u.nombre, 
    COUNT(p.id) AS TotalPedidosGestionados
FROM Empleados e
JOIN Usuarios u ON e.usuarioId = u.id
JOIN Pedidos p ON e.id = p.empleadoId
GROUP BY e.id, u.nombre
HAVING COUNT(p.id) > (
    -- SUBCONSULTA: Calculamos la media de pedidos por empleado
    SELECT COUNT(*) / COUNT(DISTINCT empleadoId) 
    FROM Pedidos
);



3. El "Cliente Exigente" (Conteo de Distintos)
Objetivo: "Lista los clientes que han comprado productos de al menos 3 Tipos diferentes (ej: Ropa, Electrónica, Hogar)."

¿Qué evalúa? El uso de COUNT(DISTINCT ...). No nos importa si compró 100 cosas, nos importa la variedad.

SQL

SELECT 
    u.nombre, 
    COUNT(DISTINCT prod.tipoProductoId) AS VariedadTipos
FROM Usuarios u
JOIN Clientes c ON u.id = c.usuarioId
JOIN Pedidos p ON c.id = p.clienteId
JOIN LineasPedido lp ON p.id = lp.pedidoId
JOIN Productos prod ON lp.productoId = prod.id
GROUP BY u.id, u.nombre
HAVING VariedadTipos >= 3; -- Solo los que superan la variedad de 3




4. La "Lista Negra" (Exclusión con NOT IN)
Objetivo: "Dime qué productos NUNCA han sido comprados por un cliente menor de 25 años."

¿Qué evalúa? Lógica inversa. Es más fácil buscar qué productos SÍ han comprado los jóvenes, y luego decir "Dame los que NO estén en esa lista".

SQL

SELECT nombre
FROM Productos
WHERE id NOT IN (
    -- SUBCONSULTA: Saco la lista de productos que SÍ han comprado los <25
    SELECT DISTINCT lp.productoId
    FROM LineasPedido lp
    JOIN Pedidos p ON lp.pedidoId = p.id
    JOIN Clientes c ON p.clienteId = c.id
    WHERE TIMESTAMPDIFF(YEAR, c.fechaNacimiento, CURDATE()) < 25
);

5. El Reporte Estacional (Agrupación por Fechas)
Objetivo: "Muestra las ventas totales (dinero) desglosadas por Año y Mes, pero solo de los meses donde se vendieron más de 1000 euros."

¿Qué evalúa? El uso de funciones de fecha en el GROUP BY y el filtro de totales en el HAVING.

SQL

SELECT 
    YEAR(p.fechaRealizacion) AS Anio,
    MONTH(p.fechaRealizacion) AS Mes,
    SUM(lp.unidades * lp.precioUnitario) AS FacturacionTotal
FROM Pedidos p
JOIN LineasPedido lp ON p.id = lp.pedidoId
GROUP BY YEAR(p.fechaRealizacion), MONTH(p.fechaRealizacion) -- Agrupo por fecha calendario
HAVING FacturacionTotal > 1000 -- Filtro los meses "malos"
ORDER BY Anio DESC, Mes DESC; -- Ordeno cronológicamente


2.1. Las 5 líneas con más unidades (1 punto)
Estrategia:

Tablas: Necesitas LineasPedido (unidades, precio) y Productos (nombre).

Orden: Te piden "las que más unidades tienen", así que ordenamos DESCendientemente.

Límite: Solo quieres 5, así que LIMIT 5.

SQL

SELECT 
    prod.nombre AS NombreProducto,
    lp.precioUnitario,
    lp.unidades
FROM LineasPedido lp
JOIN Productos prod ON lp.productoId = prod.id
ORDER BY lp.unidades DESC -- Ordenamos de mayor a menor cantidad
LIMIT 5; -- Cortamos para mostrar solo el Top 5



2.3. Pedidos antiguos con totales y empleados opcionales (2 puntos)
Este es un ejercicio "filtro" (para separar aprobar de sacar nota). Analicemos por qué:

"Precio total" y "Unidades totales": Estos datos NO están en la tabla Pedidos. Tienes que calcularlos sumando las líneas (SUM). Esto te obliga a usar GROUP BY.

"Si un pedido no tiene empleado...": Esto te OBLIGA a usar LEFT JOIN. Si usas INNER JOIN, los pedidos sin empleado desaparecerían del listado.

"Más de 7 días de antigüedad": Usamos DATEDIFF o resta de fechas.

La Solución:

SQL

SELECT 
    u.nombre AS NombreEmpleado,
    p.fechaRealizacion,
    SUM(lp.precioUnitario * lp.unidades) AS PrecioTotalPedido, -- Calculado
    SUM(lp.unidades) AS UnidadesTotalesPedido -- Calculado
FROM Pedidos p
JOIN LineasPedido lp ON p.id = lp.pedidoId -- Unimos para sacar los cálculos
LEFT JOIN Empleados e ON p.empleadoId = e.id -- LEFT JOIN: Queremos el pedido aunque no tenga empleado
LEFT JOIN Usuarios u ON e.usuarioId = u.id -- LEFT JOIN: Para llegar al nombre
WHERE DATEDIFF(CURDATE(), p.fechaRealizacion) > 7 -- Filtro de antigüedad
GROUP BY p.id, p.fechaRealizacion, u.nombre; -- Agrupamos por el pedido



2.1. Listado mensual de empleados y clientes (1 punto)
El Reto: Necesitas sacar nombres de dos personas distintas (Empleado y Cliente) en la misma fila. Como ambos nombres están en la tabla Usuarios, tendrás que unir la tabla Usuarios dos veces usando alias diferentes.

Solución:

SQL

SELECT 
    u_emp.nombre AS NombreEmpleado,
    p.fechaRealizacion,
    u_cli.nombre AS NombreCliente
FROM Pedidos p
-- 1. Camino hacia el Empleado
JOIN Empleados e ON p.empleadoId = e.id
JOIN Usuarios u_emp ON e.usuarioId = u_emp.id -- Alias 'u_emp' para el empleado
-- 2. Camino hacia el Cliente
JOIN Clientes c ON p.clienteId = c.id
JOIN Usuarios u_cli ON c.usuarioId = u_cli.id -- Alias 'u_cli' para el cliente
-- 3. Filtro: "Este mes"
WHERE MONTH(p.fechaRealizacion) = MONTH(CURDATE()) 
  AND YEAR(p.fechaRealizacion) = YEAR(CURDATE());


  2.2. Clientes VIP del último año (2 puntos)
El Reto: Aquí hay una TRAMPA MORTAL. Te piden filtrar por "más de 5 pedidos". Como necesitas sumar importes, tienes que hacer JOIN con LineasPedido.

Problema: Si un pedido tiene 10 líneas (10 productos distintos), al hacer COUNT(p.id) te saldrá 10, no 1.

Solución: Tienes que usar COUNT(DISTINCT p.id) para contar pedidos únicos, ignorando cuántas líneas tienen dentro.

Solución:

SQL

SELECT 
    u.nombre AS NombreCliente,
    SUM(lp.unidades) AS UnidadesTotales,
    SUM(lp.unidades * lp.precioUnitario) AS ImporteTotalGastado
FROM Clientes c
JOIN Usuarios u ON c.usuarioId = u.id
JOIN Pedidos p ON c.id = p.clienteId
JOIN LineasPedido lp ON p.id = lp.pedidoId
-- 1. Filtro de Tiempo: "Último año" (Desde hace 365 días hasta hoy)
WHERE p.fechaRealizacion >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
-- 2. Agrupación por Cliente
GROUP BY c.id, u.nombre
-- 3. Filtro de Cantidad: "Más de 5 pedidos"
HAVING COUNT(DISTINCT p.id) > 5; -- <--- ¡LA CLAVE ESTÁ AQUÍ!