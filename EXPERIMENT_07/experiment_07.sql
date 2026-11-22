-- ============================================================================
-- EXPERIMENT 07: Step-by-Step Normalization (UNF to BCNF) & Lossless Join Verification
-- Student Name : Arush Gupta
-- UID          : 25LBCS3097
-- Course       : DBMS Laboratory (MySQL 8.0+)
-- ============================================================================
-- Aim: To identify functional dependencies (FDs) in a denormalized Sales_Raw
--      relation, decompose it step-by-step through 1NF, 2NF, 3NF, and BCNF,
--      and verify the lossless-join property (zero spurious tuples) and
--      dependency preservation using MySQL queries.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Database Initialization & Safe Reset
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS Sales_Normalization;
USE Sales_Normalization;

DROP TABLE IF EXISTS Order_Items;
DROP TABLE IF EXISTS Orders_BCNF;
DROP TABLE IF EXISTS Sales_Rep_Region;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Sales_1NF;

-- ----------------------------------------------------------------------------
-- STEP 2: 1NF Table (Atomic values, Composite PK: Order_ID, Product_ID)
-- ----------------------------------------------------------------------------
CREATE TABLE Sales_1NF (
    Order_ID INT,
    Product_ID INT,
    Cust_ID INT,
    Cust_Name VARCHAR(50),
    Cust_City VARCHAR(50),
    Prod_Name VARCHAR(60),
    Unit_Price DECIMAL(10,2),
    Qty INT,
    Sales_Rep_ID INT,
    Region VARCHAR(30),
    PRIMARY KEY (Order_ID, Product_ID)
);

INSERT INTO Sales_1NF VALUES
(1001, 501, 11, 'Aarav Sharma', 'Lucknow', 'Wireless Mouse', 799.00, 2, 901, 'North'),
(1001, 502, 11, 'Aarav Sharma', 'Lucknow', 'Mechanical Keyboard', 2499.00, 1, 901, 'North'),
(1002, 501, 12, 'Priya Nair', 'Bengaluru', 'Wireless Mouse', 799.00, 3, 902, 'South'),
(1003, 503, 13, 'Rohan Gupta', 'Delhi', 'USB-C Hub', 1299.00, 1, 901, 'North');

-- ----------------------------------------------------------------------------
-- STEP 3: Decompose into BCNF Tables
-- ----------------------------------------------------------------------------
-- Relation 1: Customers (Cust_ID -> Cust_Name, Cust_City)
CREATE TABLE Customers AS
SELECT DISTINCT Cust_ID, Cust_Name, Cust_City FROM Sales_1NF;
ALTER TABLE Customers ADD PRIMARY KEY (Cust_ID);

-- Relation 2: Sales_Rep_Region (Sales_Rep_ID -> Region)
CREATE TABLE Sales_Rep_Region AS
SELECT DISTINCT Sales_Rep_ID, Region FROM Sales_1NF;
ALTER TABLE Sales_Rep_Region ADD PRIMARY KEY (Sales_Rep_ID);

-- Relation 3: Orders_BCNF (Order_ID -> Cust_ID, Sales_Rep_ID)
CREATE TABLE Orders_BCNF AS
SELECT DISTINCT Order_ID, Cust_ID, Sales_Rep_ID FROM Sales_1NF;
ALTER TABLE Orders_BCNF ADD PRIMARY KEY (Order_ID);

-- Relation 4: Products (Product_ID -> Prod_Name, Unit_Price)
CREATE TABLE Products AS
SELECT DISTINCT Product_ID, Prod_Name, Unit_Price FROM Sales_1NF;
ALTER TABLE Products ADD PRIMARY KEY (Product_ID);

-- Relation 5: Order_Items (Order_ID, Product_ID -> Qty)
CREATE TABLE Order_Items AS
SELECT Order_ID, Product_ID, Qty FROM Sales_1NF;
ALTER TABLE Order_Items ADD PRIMARY KEY (Order_ID, Product_ID);

-- ----------------------------------------------------------------------------
-- STEP 4: Verification of Lossless Join
-- ----------------------------------------------------------------------------
SELECT '--- Lossless Join Row Count Verification ---' AS Verification_Step;
SELECT
    (SELECT COUNT(*) FROM Sales_1NF) AS Original_1NF_Row_Count,
    (SELECT COUNT(*)
     FROM Order_Items oi
     INNER JOIN Orders_BCNF o ON oi.Order_ID = o.Order_ID
     INNER JOIN Customers c ON o.Cust_ID = c.Cust_ID
     INNER JOIN Sales_Rep_Region sr ON o.Sales_Rep_ID = sr.Sales_Rep_ID
     INNER JOIN Products p ON oi.Product_ID = p.Product_ID
    ) AS Reconstructed_BCNF_Row_Count;

-- Reconstructed data view
SELECT '--- Reconstructed Relation via Natural Joins ---' AS Verification_Step;
SELECT o.Order_ID, oi.Product_ID, c.Cust_ID, c.Cust_Name, p.Prod_Name, oi.Qty, sr.Sales_Rep_ID, sr.Region
FROM Order_Items oi
JOIN Orders_BCNF o ON oi.Order_ID = o.Order_ID
JOIN Customers c ON o.Cust_ID = c.Cust_ID
JOIN Sales_Rep_Region sr ON o.Sales_Rep_ID = sr.Sales_Rep_ID
JOIN Products p ON oi.Product_ID = p.Product_ID;

-- ----------------------------------------------------------------------------
-- STEP 5: Verification of Functional Dependency Preservation
-- ----------------------------------------------------------------------------
SELECT '--- Functional Dependency Preservation Test (Returns 0 violating groups) ---' AS Verification_Step;
SELECT Cust_ID, COUNT(DISTINCT Cust_Name) AS Name_Variants
FROM Customers
GROUP BY Cust_ID
HAVING COUNT(DISTINCT Cust_Name) > 1;
