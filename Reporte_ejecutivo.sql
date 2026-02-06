/* 
    REPORTE EJECUTIVO DE IMPACTO


	• 	¿Cómo van las ventas respecto al periodo anterior?
	• 	¿Quiénes son nuestros mejores clientes?
	• 	¿Qué productos son más vendidos y más rentables?
	• 	¿Estamos creciendo o perdiendo participación?

*/

-- VENTAS TOTALES Y CRECIMIENTO

WITH Ventas AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        CAST(SUM(TotalDue) AS DECIMAL(18,2)) AS VentasTotales
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Año,
    Mes,
    VentasTotales,
    LAG(VentasTotales) OVER (ORDER BY Año, Mes) AS VentasMesAnterior,
    (VentasTotales - LAG(VentasTotales) OVER (ORDER BY Año, Mes)) * 100.0
        / NULLIF(LAG(VentasTotales) OVER (ORDER BY Año, Mes), 0) AS CrecimientoMoM
FROM Ventas
ORDER BY Año, Mes;

-- TICKET PROMEDIO (AOV)

SELECT
    YEAR(soh.OrderDate) AS Año,
    MONTH(soh.OrderDate) AS Mes,
    CAST(AVG(soh.TotalDue) AS DECIMAL(18,2)) AS TicketPromedio
FROM Sales.SalesOrderHeader soh
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
ORDER BY Año, Mes;

-- TOP 5 CLIENTES

SELECT TOP 5
	p.FirstName + ' ' + p.LastName AS Cliente,
    c.CustomerID,
    SUM(soh.TotalDue) AS TotalComprado
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
INNER JOIN Person.Person p  ON C.CustomerID = P.BusinessEntityID 
GROUP BY c.CustomerID, p.FirstName , p.LastName 
ORDER BY TotalComprado DESC;
 

-- TOP 5 PRODUCTOS MÁS VENDIDOS

SELECT TOP 5
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    SUM(sod.LineTotal) AS Ingresos,
    SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS Utilidad
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY UnidadesVendidas DESC;

-- TOP 5 PRODUCTOS MÁS RENTABLES

SELECT TOP 5
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    SUM(sod.LineTotal) AS Ingresos,
    SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS Utilidad
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY Utilidad  DESC;

-- RENTABILIDAD PROMEDIO

SELECT
    SUM(sod.LineTotal) AS VentasTotales,
    SUM(sod.OrderQty * p.StandardCost) AS CostoTotal,
    SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS UtilidadTotal,
    CAST(
        SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) * 100.0
        / NULLIF(SUM(sod.LineTotal), 0)
        AS DECIMAL(5,2)
    ) AS MargenPorcentaje
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID;

-- REPORTE EJECUTIVO MENSUAL 

WITH Ventas AS (
    SELECT
        YEAR(OrderDate) AS Año,
        MONTH(OrderDate) AS Mes,
        SUM(TotalDue) AS VentasTotales
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    v.Año,
    v.Mes,
    v.VentasTotales,
    LAG(v.VentasTotales) OVER (ORDER BY v.Año, v.Mes) AS VentasMesAnterior,
    (v.VentasTotales - LAG(v.VentasTotales) OVER (ORDER BY v.Año, v.Mes))
        / NULLIF(LAG(v.VentasTotales) OVER (ORDER BY v.Año, v.Mes),0) * 100.0 AS CrecimientoMoM,
    (SELECT AVG(TotalDue)
     FROM Sales.SalesOrderHeader soh
     WHERE YEAR(soh.OrderDate)=v.Año AND MONTH(soh.OrderDate)=v.Mes) AS TicketPromedio
FROM Ventas v;






































