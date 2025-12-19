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