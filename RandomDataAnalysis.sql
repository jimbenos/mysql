-- =============================================
-- Author:		<Jimrey Benos>
-- Create date: <8/4/2023>
-- Description:	Random data analysis
-- =============================================

-- Query 1:
-- Created own table
-- Find duplicates in the table.
-- Using a window function method and EXISTS operator

--DROP TABLE users;
CREATE TABLE users
(
user_id INT PRIMARY KEY,
user_name VARCHAR(30) not null,
email VARCHAR(50));

INSERT INTO users VALUES
(1, 'Jimrey', 'Jimrey@gmail.com'),
(2, 'Nathalia', 'Nathalia@gmail.com'),
(3, 'Stephanie', 'Stephanie@gmail.com'),
(4, 'Lance', 'Lance@gmail.com'),
(5, 'James', 'James@gmail.com'),
(6, 'Theodora', 'Theodora@gmail.com'),
(7, 'Theodora', 'Theodora@gmail.com');

SELECT * FROM users;

--WINDOW FUNCTION METHOD
SELECT user_id, user_name, email
FROM (
SELECT *,
row_number() OVER (PARTITION BY user_name ORDER BY user_id) AS rn
FROM users u) a
WHERE a.rn <> 1;

--EXISTS with a SUB_QUERY METHOD
SELECT *
FROM users AS t1
WHERE EXISTS (
    SELECT 1
    FROM users AS t2
    WHERE t1.user_name = t2.user_name
    AND t1.user_id <> t2.user_id 
	/* "AND t1.user_id <> t2.user_id" condition refines the selection by ensuring that the 
	user_id in the outer query (t1) is not equal to the user_id in the inner query (t2).*/
);

-----------------------------------------------------------------------------------------------
-- Query 2:
-- Output the lowest and hight BaseRate in each Department

WITH MinBaseRate AS (
    SELECT DepartmentName, MIN(BaseRate) AS Min_BaseRate
    FROM [AdventureWorksDW2022].[dbo].[DimEmployee]
    GROUP BY DepartmentName
),
MaxBaseRate AS (
    SELECT DepartmentName, MAX(BaseRate) AS Max_BaseRate
    FROM [AdventureWorksDW2022].[dbo].[DimEmployee]
    GROUP BY DepartmentName
)
SELECT e.DepartmentName, 
       mn.Min_BaseRate, 
       mx.Max_BaseRate
FROM (SELECT DISTINCT DepartmentName FROM [AdventureWorksDW2022].[dbo].[DimEmployee]) e
JOIN MinBaseRate mn ON e.DepartmentName = mn.DepartmentName
JOIN MaxBaseRate mx ON e.DepartmentName = mx.DepartmentName;

------------------------------------------------------------------------------------------------------------------------
-- Query 3:
-- Output TotalProfit per ProductKey
-- Display all CustomerKey

SELECT
    ProductKey,
    UnitPrice,
	CustomerKey,
    SUM(SalesAmount - TotalProductCost) OVER (PARTITION BY ProductKey) AS TotalProfit
FROM [AdventureWorksDW2022].[dbo].[FactInternetSales];

-- Outputs all rows from the table partitioned by ProductKey and showing the TotalProfit per Product
-----------------------------------------------------------------------------------------------------------------------
--Query 4: 
-- Order the prospective buyers by YearlyIncome
-- Grouped by the Occupation
-- Calculate average yearly income by occupation

SELECT 
	FirstName + LastName AS FullName,
	Occupation, 
	Education,
	YearlyIncome,
	ROW_NUMBER() OVER(PARTITION BY Occupation ORDER BY YearlyIncome DESC) AS RowNumber,
	AVG(YearlyIncome) OVER(PARTITION BY Occupation) AS AvgYearlyIncome
FROM [AdventureWorksDW2022].[dbo].[ProspectiveBuyer]

-----------------------------------------------------------------------------------------------------------------------
-- Query 5: Cumulative Total Calculation
