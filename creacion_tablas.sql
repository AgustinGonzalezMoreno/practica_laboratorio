DROP TABLE IF EXISTS LineasPedido;
DROP TABLE IF EXISTS Productos;
DROP TABLE IF EXISTS TiposProducto;
DROP TABLE IF EXISTS Pedidos;
DROP TABLE IF EXISTS Clientes;
DROP TABLE IF EXISTS Empleados;
DROP TABLE IF EXISTS Usuarios;

CREATE TABLE Usuarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    contraseña VARCHAR(255) NOT NULL CHECK (CHAR_LENGTH(contraseña) >= 8),
    nombre VARCHAR(255) NOT NULL
);

CREATE TABLE Empleados (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuarioId INT NOT NULL,
    salario DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (usuarioId) REFERENCES Usuarios(id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE TABLE Clientes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuarioId INT NOT NULL,
    direccionEnvio VARCHAR(255) NOT NULL,
    codigoPostal VARCHAR(10) NOT NULL,
    fechaNacimiento DATE NOT NULL,
    FOREIGN KEY (usuarioId) REFERENCES Usuarios(id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE TABLE Pedidos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    fechaRealizacion DATE NOT NULL,
    fechaEnvio DATE,
    direccionEntrega VARCHAR(255) NOT NULL,
    comentarios TEXT,
    clienteId INT NOT NULL,
    empleadoId INT,
    FOREIGN KEY (clienteId) REFERENCES Clientes(id) 
        ON DELETE RESTRICT 
        ON UPDATE RESTRICT,
    FOREIGN KEY (empleadoId) REFERENCES Empleados(id) 
        ON DELETE SET NULL 
        ON UPDATE SET NULL
);

CREATE TABLE TiposProducto (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(255) NOT NULL
);

CREATE TABLE Productos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(255) NOT NULL,
    descripción TEXT,
    precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
    tipoProductoId INT NOT NULL,
    puedeVenderseAMenores BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (tipoProductoId) REFERENCES TiposProducto(id)
);

CREATE TABLE LineasPedido (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pedidoId INT NOT NULL,
    productoId INT NOT NULL,
    unidades INT NOT NULL CHECK (unidades > 0 AND unidades <= 100),
    precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
    FOREIGN KEY (pedidoId) REFERENCES Pedidos(id),
    FOREIGN KEY (productoId) REFERENCES Productos(id),
    UNIQUE (pedidoId, productoId)
);




-- 1. LIMPIEZA PREVIA (Opcional pero recomendado para evitar errores al probar)
DROP TABLE IF EXISTS [NOMBRE_TABLA];

-- 2. CREACIÓN DE LA TABLA
CREATE TABLE [NOMBRE_TABLA] (
    -- A. IDENTIFICADOR (Casi siempre es igual)
    id INT PRIMARY KEY AUTO_INCREMENT,

    -- B. COLUMNAS DE DATOS (Rellena según el enunciado)
    [nombre_columna_texto] VARCHAR(255) NOT NULL,
    [nombre_columna_numero] INT NOT NULL DEFAULT 0,
    [nombre_columna_fecha] DATE,
    [nombre_columna_dinero] DECIMAL(10, 2) CHECK ([nombre_columna_dinero] >= 0),
    
    -- C. COLUMNAS PARA CLAVES FORÁNEAS (Solo si conecta con otra tabla)
    [otraTablaId] INT NOT NULL,

    -- D. RESTRICCIONES DE NEGOCIO (Validaciones extra)
    -- Ejemplo: Un email único o una edad mínima
    UNIQUE ([nombre_columna_texto]), 
    CHECK ([nombre_columna_numero] > 0),

    -- E. DEFINICIÓN DE CLAVES FORÁNEAS (Conexiones)
    FOREIGN KEY ([otraTablaId]) REFERENCES [OTRA_TABLA](id)
        ON DELETE [RESTRICT | CASCADE | SET NULL]
        ON UPDATE [RESTRICT | CASCADE | SET NULL]
);



1. Solución al ejercicio: Tabla PagosAnálisis de requisitos:Relación: Un pedido tiene muchos pagos ($1:N$). La FK (pedidoId) va en la tabla Pagos.Restricción: Cantidad no negativa (CHECK).Valor por defecto: Revisado = No (DEFAULT FALSE).Borrado: Al ser dinero, lo profesional es RESTRICT (no me borres el pedido si ya hay dinero pagado).SQLCREATE TABLE Pagos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pedidoId INT NOT NULL,
    fechaPago DATETIME NOT NULL DEFAULT NOW(), -- Ponemos DATETIME para ser precisos
    cantidad DECIMAL(10, 2) NOT NULL CHECK(cantidad >= 0),
    revisado BOOLEAN NOT NULL DEFAULT FALSE, -- Por defecto NO está revisado
    
    FOREIGN KEY (pedidoId) REFERENCES Pedidos(id)
        ON DELETE RESTRICT -- Seguridad financiera: No borres el pedido si ya hay pagos
        ON UPDATE CASCADE
);

2. Posible Variante: Tabla Reseñas (Valoraciones)
Enunciado probable: "Los usuarios pueden valorar los productos que han comprado. Queremos guardar una puntuación del 1 al 5, un comentario de texto y la fecha. Un usuario solo puede valorar una vez el mismo producto."

Claves:

Relación con Usuarios y con Productos.

Restricción de rango (1-5).

Restricción de Unicidad (Usuario + Producto).

SQL

CREATE TABLE Resenas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuarioId INT NOT NULL,
    productoId INT NOT NULL,
    puntuacion INT NOT NULL CHECK(puntuacion BETWEEN 1 AND 5), -- Nota del 1 al 5
    comentario TEXT,
    fecha DATETIME NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (usuarioId) REFERENCES Usuarios(id)
        ON DELETE CASCADE, -- Si se borra el usuario, sus opiniones dan igual
        
    FOREIGN KEY (productoId) REFERENCES Productos(id)
        ON DELETE CASCADE, -- Si se borra el producto, borramos sus reseñas
        
    UNIQUE(usuarioId, productoId) -- ¡Vital! Un usuario no puede opinar 2 veces de lo mismo
);


3. Posible Variante: Tabla Proveedores (Relación 1:N)
Enunciado probable: "Queremos saber quién nos suministra los productos. Crea una tabla de Proveedores (Nombre, CIF, Teléfono). Cada producto pertenece a un único proveedor."

OJO AQUÍ: Esto implica crear la tabla nueva Y MODIFICAR la tabla Productos para añadir la flecha (ALTER TABLE). Pero si te piden crearla de cero asumiendo que Productos ya tiene el campo, sería así:

SQL

-- 1. Primero creamos al "Padre"
CREATE TABLE Proveedores (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombreEmpresa VARCHAR(100) NOT NULL,
    cif VARCHAR(20) UNIQUE NOT NULL, -- El CIF no se puede repetir
    telefono VARCHAR(15)
);

-- 2. En el examen, si te piden modificar Productos para enlazarlo:
ALTER TABLE Productos 
ADD COLUMN proveedorId INT,
ADD CONSTRAINT fk_producto_proveedor 
    FOREIGN KEY (proveedorId) REFERENCES Proveedores(id)
    ON DELETE RESTRICT; -- No borres al proveedor si tiene productos en venta


1. Tabla Envios (Logística)
¿Qué evalúa? Relación 1:1 (o 1:N) con Pedidos y validación de estados (Listas cerradas).

El Enunciado:"Queremos gestionar el transporte. Un pedido genera un envío. Del envío necesitamos saber la empresa de transporte, el código de seguimiento (que es único) y el estado (solo puede ser 'Pendiente', 'En Camino' o 'Entregado')."

SQL

CREATE TABLE Envios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pedidoId INT NOT NULL, -- Relación con el pedido
    empresaTransporte VARCHAR(100) NOT NULL,
    codigoSeguimiento VARCHAR(50) UNIQUE NOT NULL, -- ¡Truco! El tracking no se repite
    
    fechaSalida DATETIME DEFAULT NOW(),
    fechaEntregaEstimada DATE,
    
    -- ¡Truco! Lista cerrada de valores (ENUM simulado con CHECK)
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('Pendiente', 'En Camino', 'Entregado')),
    
    FOREIGN KEY (pedidoId) REFERENCES Pedidos(id)
        ON DELETE RESTRICT -- No borres el pedido si ya lo he enviado
);


2. Tabla CuponesDescuento (Marketing)
¿Qué evalúa? Validaciones matemáticas (CHECK) y fechas de caducidad.

El Enunciado: "La tienda quiere usar códigos de descuento (ej: 'VERANO2025'). Cada cupón tiene un código único, un porcentaje de descuento (entre 1% y 90%), una fecha de caducidad y un booleano para desactivarlo manualmente."

SQL

CREATE TABLE CuponesDescuento (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(20) UNIQUE NOT NULL, -- El código "REBAJAS" solo existe una vez
    
    -- Validación matemática: Porcentaje lógico
    porcentajeDescuento INT NOT NULL CHECK (porcentajeDescuento > 0 AND porcentajeDescuento <= 90),
    
    fechaCaducidad DATE NOT NULL,
    activo BOOLEAN DEFAULT TRUE, -- Por defecto funciona
    
    -- Opcional: ¿Cuántas veces se puede usar?
    usosMaximos INT DEFAULT 1 CHECK (usosMaximos > 0)
);

(Nota: Luego te pedirían añadir una columna cuponId en la tabla Pedidos para enlazarlo).


3. Tabla Devoluciones (Post-Venta)
¿Qué evalúa? Relación con Pedidos y uso de campos de texto largo (TEXT).

El Enunciado: "Los clientes pueden devolver un pedido. Necesitamos guardar la fecha de la solicitud, el motivo de la devolución (texto largo) y si ha sido aceptada o rechazada por la tienda."

SQL

CREATE TABLE Devoluciones (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pedidoId INT NOT NULL,
    fechaSolicitud DATETIME DEFAULT NOW(),
    
    motivo TEXT NOT NULL, -- TEXT para que se explayen
    
    estado VARCHAR(20) DEFAULT 'Pendiente' 
        CHECK (estado IN ('Pendiente', 'Aceptada', 'Rechazada')),
        
    comentariosAdmin TEXT, -- Respuesta de la tienda
    
    FOREIGN KEY (pedidoId) REFERENCES Pedidos(id)
        ON DELETE CASCADE -- Si borro el pedido (raro), borro su devolución
);


4. Tabla Etiquetas + Tabla Intermedia (Categorización N:M)
¿Qué evalúa? Relaciones Muchos a Muchos (N:M). Esta es la "Matrícula de Honor".

El Enunciado: "Un producto puede tener muchas etiquetas (ej: 'Oferta', 'Nuevo', 'Eco') y una etiqueta puede estar en muchos productos. Diseña las tablas necesarias."

Solución: Necesitas DOS tablas. Una para el nombre de la etiqueta y otra para unirla con los productos.

SQL

-- 1. La tabla simple
CREATE TABLE Etiquetas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50) UNIQUE NOT NULL -- 'Oferta', 'Eco', etc.
);

-- 2. La tabla intermedia (El puente)
CREATE TABLE ProductoEtiquetas (
    productoId INT NOT NULL,
    etiquetaId INT NOT NULL,
    
    PRIMARY KEY (productoId, etiquetaId), -- Clave compuesta (Evita duplicados)
    
    FOREIGN KEY (productoId) REFERENCES Productos(id)
        ON DELETE CASCADE, -- Si borro el producto, quito la etiqueta
        
    FOREIGN KEY (etiquetaId) REFERENCES Etiquetas(id)
        ON DELETE CASCADE -- Si elimino la etiqueta 'Eco', se quita de todos los productos
);


