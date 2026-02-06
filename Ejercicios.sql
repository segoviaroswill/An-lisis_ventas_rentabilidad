SELECT * 
from sales.SalesOrderHeader soh

SELECT *
FROM SALES.SalesOrderDetail sod 

SELECT *
FROM Production.Product p 

---Venta por mes

SELECT 
	YEAR(soh.OrderDate ) AS Año,
	MONTH(SOH.OrderDate) AS Mes,
	SUM(soh.TotalDue ) AS Ventas
FROM SALES.SalesOrderHeader soh 
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
ORDER BY Año, Mes;

-- Comparacíon mes a mes (MOM)

-- CON LAG (FUNCIÓN VENTANA) USANDO CTE

WITH VentasMensuales AS (
	SELECT 
		YEAR(OrderDate) AS Año,
		MONTH(OrderDate) AS Mes,
		SUM(TotalDue) AS VentasMes
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT 
	Año,
	Mes,
	VentasMes,
	LAG(VentasMes) OVER(ORDER BY Año, Mes) AS VentaMesAnterior,
	VentasMes - LAG(VentasMes) OVER(ORDER BY Año, Mes) AS Diferencia,
	ROUND(
		(CAST(VentasMes AS FLOAT) - LAG(VentasMes) OVER (ORDER BY Año, Mes))
		/ NULLIF(LAG(VentasMes) OVER (ORDER BY Año, Mes), 0) * 100, 2
	) AS VariacionPorcentual
FROM VentasMensuales 
ORDER BY Año, Mes;

-- SIN LAG (HACER JOIN CONTRA SI MISMA)

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    v1.Año,
    v1.Mes,
    v1.VentasMes,
    v2.VentasMes AS VentasMesAnterior,
    v1.VentasMes - v2.VentasMes AS Diferencia,
    ROUND(
        (CAST(v1.VentasMes AS FLOAT) - v2.VentasMes) 
        / NULLIF(v2.VentasMes, 0) * 100, 
        2
    ) AS VariacionPorcentual
FROM VentasMensuales v1
LEFT JOIN VentasMensuales v2
    ON (v1.Año = v2.Año AND v1.Mes = v2.Mes + 1)       -- mes anterior dentro del mismo año
    OR (v1.Año = v2.Año + 1 AND v1.Mes = 1 AND v2.Mes = 12) -- diciembre → enero
ORDER BY v1.Año, v1.Mes;

-- Princio de Pareto

-- Paso 1 Ventas por producto
SELECT 
	P.ProductID,
	P.Name,
	SUM(SO.OrderQty) AS CantidadVendida,
	SUM(SO.LineTotal) AS VentasTotales
FROM Sales.SalesOrderDetail so JOIN Production.Product p 
	on so.ProductID = p.ProductID 
GROUP BY p.ProductID , p.Name 
ORDER BY VentasTotales DESC

-- Paso 2 5 productos mas vendidos
SELECT TOP 5
	P.ProductID,
	P.Name,
	SUM(SO.OrderQty) AS CantidadVendida,
	SUM(SO.LineTotal) AS VentasTotales
FROM Sales.SalesOrderDetail so JOIN Production.Product p 
	on so.ProductID = p.ProductID 
GROUP BY p.ProductID , p.Name 
ORDER BY VentasTotales DESC


-- RANKING COMO FUNCIÓN VENTANA

WITH RankingProductos AS (
    SELECT
        p.ProductID,
        p.Name AS Producto,
        SUM(so.OrderQty) AS CantidadVendida,
        SUM(so.LineTotal) AS VentasTotales,
        RANK() OVER (ORDER BY SUM(so.LineTotal) DESC) AS Posicion
    FROM Sales.SalesOrderDetail so
    JOIN Production.Product p
        ON so.ProductID = p.ProductID
    GROUP BY p.ProductID, p.Name
)
SELECT *
FROM RankingProductos
WHERE Posicion <= 5
ORDER BY Posicion;
	
-- Analizar el precio promedio por producto y categoría

-- 1 Precio promedio por producto (Ver cuáles productos tienen el precio promedio más alto o baja)

SELECT 
	P.ProductID,
	P.Name,
	ROUND(AVG(SOD.UnitPrice), 2) AS PrecioPromedio
FROM SALES.SalesOrderDetail sod 
JOIN Production.Product p 
	ON SOD.ProductID = P.ProductID 
GROUP BY P.ProductID, P.Name 
ORDER BY PrecioPromedio DESC 

-- 2 Precio promedio por categoria 

SELECT 
	s.Name Subcategoria,
	ROUND(AVG(SOD.UnitPrice), 2) AS PrecioPromedio
FROM SALES.SalesOrderDetail sod 
JOIN Production.Product p 
	ON SOD.ProductID = P.ProductID 
JOIN Production.ProductSubcategory s
	ON P.ProductSubcategoryID = s.ProductCategoryID 
GROUP BY s.Name 
ORDER BY PrecioPromedio DESC 

SELECT 
	C.Name Categoria,
	s.Name Subcategoria,
	ROUND(AVG(SOD.UnitPrice), 2) AS PrecioPromedio
FROM SALES.SalesOrderDetail sod 
JOIN Production.Product p 
	ON SOD.ProductID = P.ProductID 
JOIN Production.ProductSubcategory s
	ON P.ProductSubcategoryID = s.ProductCategoryID 
JOIN Production.ProductCategory c
	ON S.ProductCategoryID = c.ProductCategoryID
GROUP BY c.Name, s.Name 
ORDER BY PrecioPromedio DESC

/*
Paso 3. Ahora vemos un resumen agregado por categoría.
Comparar producto vs. categoría.
Si queremos saber qué tan caro o barato es un producto respecto al promedio de su categoría, podemos usar una subconsulta o funciones ventana.

Así sabemos si un producto está por encima o debajo del promedio de su categoría.
*/

WITH Promedios AS (
    SELECT
        p.ProductID,
        p.Name AS Producto,
        pc.Name AS Categoria,
        AVG(sod.UnitPrice) AS PrecioPromedioProducto,
        AVG(AVG(sod.UnitPrice)) OVER (PARTITION BY pc.Name) AS PrecioPromedioCategoria
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory ps
        ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    JOIN Production.ProductCategory pc
        ON ps.ProductCategoryID = pc.ProductCategoryID
    GROUP BY p.ProductID, p.Name, pc.Name
)
SELECT
    Categoria,
    Producto,
    ROUND(PrecioPromedioProducto, 2) AS PrecioPromedioProducto,
    ROUND(PrecioPromedioCategoria, 2) AS PrecioPromedioCategoria,
    ROUND(PrecioPromedioProducto - PrecioPromedioCategoria, 2) AS Diferencia
FROM Promedios
ORDER BY Categoria, Diferencia DESC;

-- Calcular el ticket promedio (AOV) por cliente

-- 1 Total ventas y número de pedidos por cliente

SELECT 
	SOH.CustomerID,
	COUNT(SOH.SalesOrderID) AS NumeroPedidos,
	SUM(SOH.TotalDue) AS VentasTotales
FROM Sales.SalesOrderHeader soh 
GROUP BY SOH.CustomerID 
ORDER BY VentasTotales DESC;

-- 2 Ticket Promedio por cliente (AOV)
	
SELECT 
	SOH.CustomerID,
	COUNT(SOH.SalesOrderID) AS NumeroPedidos,
	SUM(SOH.TotalDue) AS VentasTotales,
	ROUND(AVG(SOH.TotalDue), 2) AS TicketPromedio -- este es el AOV
FROM Sales.SalesOrderHeader soh 
GROUP BY SOH.CustomerID 
ORDER BY VentasTotales DESC;

-- 3 MOSTRA MAS DETALLE DE LOS CLIENTES

SELECT 
	SOH.CustomerID,
	P.FirstName + ' ' + p.LastName AS Cliente,
	COUNT(SOH.SalesOrderID) AS NumeroPedidos,
	SUM(SOH.TotalDue) AS VentasTotales,
	ROUND(AVG(SOH.TotalDue), 2) AS TicketPromedio -- este es el AOV
FROM Sales.SalesOrderHeader soh 
INNER JOIN Sales.Customer c 
	ON SOH.CustomerID = C.CustomerID 
INNER JOIN  Person.Person p
	ON C.PersonID = P.BusinessEntityID
GROUP BY SOH.CustomerID, p.firstname, p.lastname
ORDER BY TicketPromedio  DESC;

-- Identificar clientes frecuentes, nuevos e inactivos

-- 1  Obtener la ultima compra y numero de pedido por clientes
	
SELECT 
	soh.CustomerID,
	COUNT(soh.SalesOrderID) AS NumeroPedidos,
	MIN(soh.OrderDate) AS PrimeraCompra,
	MAX(soh.OrderDate) AS UltimaCompra
FROM Sales.SalesOrderHeader soh 
GROUP BY soh.CustomerID;

-- Paso 2 Definir reglas de segmentación
--Supongamos que la empresa define:
--   - Frecuente = 5 o más pedidos en total, y última compra en los últimos 180 días.
--   - Nuevo = primera compra en los últimos 90 días.
--   - Inactivo = última compra hace más de 365 días.

--           (Los valores de días son personalizables según el negocio.)


-- 3

WITH Clientes AS (
    SELECT
        soh.CustomerID,
        COUNT(soh.SalesOrderID) AS NumeroPedidos,
        MIN(soh.OrderDate) AS PrimeraCompra,
        MAX(soh.OrderDate) AS UltimaCompra
    FROM Sales.SalesOrderHeader soh
    GROUP BY soh.CustomerID
)
SELECT
    c.CustomerID,
    CASE
        WHEN c.PrimeraCompra >= DATEADD(DAY, -90, GETDATE()) THEN 'Nuevo'
        WHEN c.NumeroPedidos >= 5 AND c.UltimaCompra >= DATEADD(DAY, -180, GETDATE()) THEN 'Frecuente'
        WHEN c.UltimaCompra < DATEADD(YEAR, -1, GETDATE()) THEN 'Inactivo'
        ELSE 'Ocasional'
    END AS Segmento,
    NumeroPedidos,
    PrimeraCompra,
    UltimaCompra
FROM Clientes c
ORDER BY Segmento, c.UltimaCompra; --TODOS INACTIVOS POR LA FECHA ANTIGUA DE LA BASE DE DATOS

SELECT MAX(OrderDate) FROM Sales.SalesOrderHeader;

	
-- 1. Tomamos la fecha más reciente del dataset
DECLARE @FechaReferencia DATE = (
    SELECT MAX(soh.OrderDate)
    FROM Sales.SalesOrderHeader soh
);

-- 2. Construimos el resumen por cliente
WITH Clientes AS (
    SELECT
        soh.CustomerID,
        COUNT(soh.SalesOrderID) AS NumeroPedidos,
        MIN(soh.OrderDate) AS PrimeraCompra,
        MAX(soh.OrderDate) AS UltimaCompra
    FROM Sales.SalesOrderHeader soh
    GROUP BY soh.CustomerID
)

-- 3. Segmentamos según reglas de negocio
SELECT
    c.CustomerID,
    CASE
        WHEN c.PrimeraCompra >= DATEADD(DAY, -90, @FechaReferencia) THEN 'Nuevo'
        WHEN c.NumeroPedidos >= 5
             AND c.UltimaCompra >= DATEADD(DAY, -180, @FechaReferencia) THEN 'Frecuente'
        WHEN c.UltimaCompra < DATEADD(YEAR, -1, @FechaReferencia) THEN 'Inactivo'
        ELSE 'Ocasional'
    END AS Segmento,
    c.NumeroPedidos,
    c.PrimeraCompra,
    c.UltimaCompra,
    @FechaReferencia AS FechaReferenciaUsada
FROM Clientes c
ORDER BY Segmento, c.UltimaCompra;
	
	
-- Mejores clientes

-- 1 Ventas totales por clientes

SELECT 
	soh.CustomerID,
	SUM(soh.TotalDue) AS VentasTotales
FROM Sales.SalesOrderHeader soh
GROUP BY soh.CustomerID;

--2 Raking de clientes por ventana

WITH VentasClientes AS(
    SELECT
        soh.CustomerID AS CustomerID,
        SUM(soh.TotalDue) AS VentasTotales
    FROM Sales.SalesOrderHeader soh
    GROUP BY soh.CustomerID
),
Ranking AS (
    SELECT
        CustomerID,
        VentasTotales,
        RANK() OVER(ORDER BY VentasTotales DESC) AS Posicion,
        SUM(VentasTotales) OVER() AS VentasGlobales,
        SUM(VentasTotales) OVER (ORDER BY VentasTotales DESC) AS VentasAcumuladas
    FROM VentasClientes
)
SELECT
    CustomerID,
    VentasTotales,
    VentasAcumuladas,
    VentasGlobales,
    ROUND(VentasAcumuladas * 100.0 / VentasGlobales, 2) AS PorcentajeAcumulado
FROM Ranking
ORDER BY Posicion;

-- VENTAS YOY O MOM

--1 VENTAS POR AÑO Y MES

SELECT 
	YEAR(OrderDate) AS AÑO,
	MONTH(OrderDate) AS MES,
	SUM(TotalDue) AS VentasMes
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY AÑO, MES;

--2 COMPARATIVO YOY

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    v1.Año,
    v1.Mes,
    v1.VentasMes,
    v2.VentasMes AS VentasMesAñoAnterior,
    v1.VentasMes - v2.VentasMes AS Diferencia,
    ROUND((CAST(v1.VentasMes AS FLOAT) - v2.VentasMes) / NULLIF(v2.VentasMes, 0) * 100, 2) AS VariacionYoY
FROM VentasMensuales v1
LEFT JOIN VentasMensuales v2
    ON v1.Mes = v2.Mes
    AND v1.Año = v2.Año + 1
ORDER BY
    v1.Año,
    v1.Mes;
	
-- COMPRACION MOM

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Año,
    Mes,
    VentasMes,
    LAG(VentasMes) OVER(ORDER BY Año, Mes) AS VentasMesAnterior,
    VentasMes - LAG(VentasMes) OVER(ORDER BY Año, Mes) AS Diferencia,
    ROUND(
        (CAST(VentasMes AS FLOAT) - LAG(VentasMes) OVER (ORDER BY Año, Mes))
        / NULLIF(LAG(VentasMes) OVER (ORDER BY Año, Mes), 0) * 100,
        2
    ) AS VariacionMoM
FROM VentasMensuales
ORDER BY Año, Mes;

-- RUNNING TOTALS

/*
Paso 2 - Acumulado (Running Total) con SUM() OVER

SUM() OVER genera el total acumulado mes a mes dentro de cada año.
*/

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Año,
    Mes,
    VentasMes,
    SUM(VentasMes) OVER (
        PARTITION BY Año
        ORDER BY Mes
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS AcumuladoAnual
FROM VentasMensuales
ORDER BY Año, Mes;

/*
Paso 3 - Running Total sin reiniciar por año (global)

Aquí el acumulado no se reinicia por año, es útil para series largas
*/

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Año,
    Mes,
    VentasMes,
    SUM(VentasMes) OVER (
        ORDER BY Año, Mes
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS AcumuladoGlobal
FROM VentasMensuales
ORDER BY Año, Mes;

/*
Paso 4 — Aplicación práctica: % de participación

Podemos usar acumulados para calcular avance hacia objetivos.

Con esto vemos qué porcentaje del total anual se ha alcanzado mes a mes.
*/

WITH VentasMensuales AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasMes
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Año,
    Mes,
    VentasMes,
    SUM(VentasMes) OVER (PARTITION BY Año ORDER BY Mes) AS AcumuladoAnual,
    ROUND(
        SUM(VentasMes) OVER (PARTITION BY Año ORDER BY Mes)
        * 100.0 / SUM(VentasMes) OVER (PARTITION BY Año),
        2
    ) AS PorcentajeAvanceAnual
FROM VentasMensuales
ORDER BY Año, Mes;

-- RAKING CATEGORICO

/*
Ranking dinámico por categorías de productos

Paso 1 - Ventas por categoría y mes

Este es el dataset base para aplicar el ranking.
*/

WITH VentasCategoriasMes AS (
    SELECT
        YEAR(soh.OrderDate) AS Año,
        MONTH(soh.OrderDate) AS Mes,
        pc.Name AS Categoria,
        SUM(sod.LineTotal) AS Ventas
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p 
        ON sod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory psc 
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc 
        ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY 
        YEAR(soh.OrderDate), 
        MONTH(soh.OrderDate), 
        pc.Name
)
SELECT *
FROM VentasCategoriasMes
ORDER BY Año, Mes, Categoria;

/*
Ranking dinámico por categorías de productos

Paso 2 – Ranking dinámico con funciones de ventana
*/

WITH VentasCategoriaMes AS (
    SELECT
        YEAR(soh.OrderDate) AS Año,
        MONTH(soh.OrderDate) AS Mes,
        pc.Name AS Categoria,
        SUM(sod.LineTotal) AS Ventas
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p 
        ON sod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory psc 
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc 
        ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY 
        YEAR(soh.OrderDate), 
        MONTH(soh.OrderDate), 
        pc.Name
)
SELECT
    Año,
    Mes,
    Categoria,
    Ventas,
    RANK() OVER(PARTITION BY Año, Mes ORDER BY Ventas DESC) AS Ranking,
    DENSE_RANK() OVER(PARTITION BY Año, Mes ORDER BY Ventas DESC) AS DenseRanking,
    ROW_NUMBER() OVER(PARTITION BY Año, Mes ORDER BY Ventas DESC) AS RowNum
FROM VentasCategoriaMes
ORDER BY Año, Mes, Ranking;

/*
Esto permite un top 3 dinámico por período.
Ranking dinámico por categorías de productos
*/

WITH VentasCategoriaMes AS (
    SELECT
        YEAR(soh.OrderDate) AS Año,
        MONTH(soh.OrderDate) AS Mes,
        pc.Name AS Categoria,
        SUM(sod.LineTotal) AS Ventas
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p 
        ON sod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory psc 
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc 
        ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY 
        YEAR(soh.OrderDate), 
        MONTH(soh.OrderDate), 
        pc.Name
)
SELECT *
FROM (
    SELECT
        Año,
        Mes,
        Categoria,
        Ventas,
        RANK() OVER(PARTITION BY Año, Mes ORDER BY Ventas DESC) AS Ranking
    FROM VentasCategoriaMes
) t
WHERE t.Ranking <= 3
ORDER BY Año, Mes, Ranking;

-- MAS VENDIDOS VS MAS RENTABLES

/*
Paso 1 – Calcular los más vendidos (cantidad)

Este ranking nos dice qué productos son más populares por volumen
*/

SELECT
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p 
    ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY UnidadesVendidas DESC;
	
/*
Paso 2 - Calcular la rentabilidad

Para calcular rentabilidad por producto necesitamos:

- LineTotal = venta (precio * cantidad - descuentos).
- Costo total = costo estándar (StandardCost * cantidad).
- Utilidad = Venta - Costo.

Aquí vamos a ver los productos más rentables.
*/

SELECT
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    SUM(p.StandardCost * sod.OrderQty) AS Costo,
    SUM(sod.LineTotal - (p.StandardCost * sod.OrderQty)) AS Utilidad
FROM Sales.SalesOrderDetail sod 
INNER JOIN Production.Product p 
    ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY Utilidad DESC;

/*
Paso 3 — Comparar más vendidos vs más rentables

Ahora podemos contrastar las posiciones en ventas vs utilidad

Podemos combinarlos en un mismo resultado:
*/

WITH Ventas AS(
    SELECT
        p.ProductID,
        SUM(sod.OrderQty) AS UnidadesVendidas,
        SUM(sod.LineTotal) AS IngresoTotal,
        SUM(p.StandardCost * sod.OrderQty) AS Costo,
        SUM(sod.LineTotal - (p.StandardCost * sod.OrderQty)) AS Utilidad
    FROM Sales.SalesOrderDetail sod 
    INNER JOIN Production.Product p 
        ON sod.ProductID = p.ProductID
    GROUP BY p.ProductID
)
SELECT
    p.Name AS Producto,
    UnidadesVendidas,
    IngresoTotal,
    Utilidad,
    RANK() OVER (ORDER BY UnidadesVendidas DESC) AS RankingPorVentas,
    RANK() OVER (ORDER BY Utilidad DESC) AS RankingPorUtilidad
FROM Ventas v 
INNER JOIN Production.Product p 
    ON v.ProductID = p.ProductID
ORDER BY RankingPorVentas, RankingPorUtilidad; --ORDER BY RankingPorUtilidad, RankingPorVentas;

--CANIBALIZACION

/*
    Paso 1 — Ventas históricas de productos en una categoría

    Por ejemplo, analizamos la categoría Bikes para ver cómo evoluciona cada modelo.

    Este dataset nos da la evolución mensual por producto dentro de la categoría Bikes.
*/

SELECT
    YEAR(soh.OrderDate) AS Año,
    MONTH(soh.OrderDate) AS Mes,
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Production.Product p
    ON sod.ProductID = p.ProductID
INNER JOIN Production.ProductSubcategory psc
    ON p.ProductSubcategoryID = psc.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc
    ON psc.ProductCategoryID = pc.ProductCategoryID
WHERE pc.Name = 'Bikes'
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate), p.Name
ORDER BY Año, Mes, UnidadesVendidas DESC;

/*
Paso 2 — Comparar participación (%) de cada producto

Más que mirar ventas absolutas, es útil ver cómo cambia el share interno de la categoría.

Esto nos permite ver si la subida de un producto implica la bajada proporcional de otro dentro de la misma categoría.
*/

WITH VentasPorProducto AS (
    SELECT
        YEAR(soh.OrderDate) AS Año,
        MONTH(soh.OrderDate) AS Mes,
        p.Name AS Producto,
        SUM(sod.OrderQty) AS UnidadesVendidas
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
    WHERE pc.Name = 'Bikes'
    GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate), p.Name
)
SELECT
    Año,
    Mes,
    UnidadesVendidas,
    CAST(
        UnidadesVendidas * 100.0 
        / SUM(UnidadesVendidas) OVER (PARTITION BY Año, Mes)
        AS DECIMAL(5,2)
    ) AS ParticipacionCategoria
FROM VentasPorProducto
ORDER BY Año, Mes, ParticipacionCategoria DESC;

/*
Detectar canibalización entre productos

Paso 3 — Comparación directa entre dos productos

Si queremos ver si Producto A canibaliza a Producto B, podemos compararlos en el tiempo:

Si cuando suben las ventas del Mountain-300 caen las del Mountain-200, tenemos evidencia de canibalización.

La función PIVOT en SQL Server se utiliza para convertir filas en columnas.
En otras palabras, permite reorganizar y resumir los datos para obtener una vista más fácil de analizar, como si fuera una tabla dinámica en Excel.
*/

WITH Ventas AS (
    SELECT
        YEAR(soh.OrderDate) AS Año,
        MONTH(soh.OrderDate) AS Mes,
        p.Name AS Producto,
        SUM(sod.OrderQty) AS UnidadesVendidas
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p 
        ON sod.ProductID = p.ProductID
    WHERE p.Name IN ('Mountain-200 Black, 46', 'Mountain-300 Black, 48') -- Ejemplo de 2 modelos similares
    GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate), p.Name
)
SELECT *
FROM Ventas
PIVOT (
    SUM(UnidadesVendidas)
    FOR Producto IN ([Mountain-200 Black, 46], [Mountain-300 Black, 48])
) AS PivotTable
ORDER BY Año, Mes;
	
	