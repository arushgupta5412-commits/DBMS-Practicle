-- ============================================================================
-- EXPERIMENT 10: 10,000-Row Dataset Generation & Five Slow Query Optimizations
-- Student Name : Arush Gupta
-- UID          : 25LBCS3097
-- Course       : DBMS Laboratory (MySQL 8.0+)
-- ============================================================================
-- Aim: To generate a 10,000-row Sales_Analytics dataset in MySQL, diagnose
--      five classic slow query anti-patterns using EXPLAIN, optimize each
--      query through sargable query rewriting and targeted B-Tree/covering
--      indexes, and compare execution times before and after optimization.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Database Initialization & Safe Reset
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS Perf_Lab_10K;
USE Perf_Lab_10K;

DROP TABLE IF EXISTS Sales_Analytics;

CREATE TABLE Sales_Analytics (
    Sale_ID INT PRIMARY KEY,
    Cust_ID INT NOT NULL,
    Region VARCHAR(20) NOT NULL,
    Category VARCHAR(30) NOT NULL,
    Payment_Mode VARCHAR(20) NOT NULL,
    Sale_Date DATE NOT NULL,
    Order_Status VARCHAR(20) NOT NULL,
    Amount DECIMAL(10,2) NOT NULL
);

-- ----------------------------------------------------------------------------
-- STEP 2: Generate 10,000 Rows via Cross-Joined Digit Tables
-- ----------------------------------------------------------------------------
INSERT INTO Sales_Analytics
SELECT
    seq.n AS Sale_ID,
    (seq.n % 500) + 1 AS Cust_ID,
    ELT((seq.n % 4) + 1, 'North', 'South', 'West', 'East') AS Region,
    ELT((seq.n % 5) + 1, 'Electronics', 'Apparel', 'Grocery', 'Home', 'Books') AS Category,
    ELT((seq.n % 4) + 1, 'UPI', 'Card', 'NetBanking', 'COD') AS Payment_Mode,
    DATE_ADD('2025-01-01', INTERVAL (seq.n % 650) DAY) AS Sale_Date,
    ELT((seq.n % 3) + 1, 'Completed', 'Pending', 'Cancelled') AS Order_Status,
    ROUND(250 + (seq.n % 4000) * 1.75, 2) AS Amount
FROM (
    SELECT a.d + b.d * 10 + c.d * 100 + d.d * 1000 + 1 AS n
    FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
    CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
) seq;

-- ----------------------------------------------------------------------------
-- STEP 3: CREATE OPTIMIZATION INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX idx_sale_date ON Sales_Analytics(Sale_Date, Amount);
CREATE INDEX idx_cat_amount ON Sales_Analytics(Category, Amount);
CREATE INDEX idx_cust_status ON Sales_Analytics(Cust_ID, Order_Status);
CREATE INDEX idx_region_cat_status_amt ON Sales_Analytics(Region, Order_Status, Category, Amount);

-- ----------------------------------------------------------------------------
-- 5 SLOW QUERIES vs OPTIMIZED REWRITES
-- ----------------------------------------------------------------------------

-- [Query 1: Non-Sargable Function on Date Column vs Sargable Range]
-- SLOW Q1 (Prevents index usage on Sale_Date):
EXPLAIN SELECT COUNT(*), SUM(Amount) FROM Sales_Analytics WHERE YEAR(Sale_Date) = 2026 AND MONTH(Sale_Date) = 5;
-- OPTIMIZED Q1 (Uses idx_sale_date covering range scan):
EXPLAIN SELECT COUNT(*), SUM(Amount) FROM Sales_Analytics
WHERE Sale_Date >= '2026-05-01' AND Sale_Date < '2026-06-01';

-- [Query 2: Correlated Subquery in WHERE vs Pre-Aggregated Derived Table JOIN]
-- SLOW Q2 (Re-evaluates AVG per row):
EXPLAIN SELECT s1.Sale_ID, s1.Category, s1.Amount FROM Sales_Analytics s1
WHERE s1.Amount > (SELECT AVG(s2.Amount) FROM Sales_Analytics s2 WHERE s2.Category = s1.Category);
-- OPTIMIZED Q2 (Computes 5 category averages once using idx_cat_amount):
EXPLAIN SELECT s1.Sale_ID, s1.Category, s1.Amount
FROM Sales_Analytics s1
INNER JOIN (
    SELECT Category, AVG(Amount) AS avg_amt FROM Sales_Analytics GROUP BY Category
) ca ON s1.Category = ca.Category AND s1.Amount > ca.avg_amt;

-- [Query 3: Disjunctive OR across columns vs UNION with Targeted Indexes]
-- SLOW Q3 (Full scan due to unindexed OR condition):
EXPLAIN SELECT Sale_ID, Cust_ID, Sale_Date, Amount FROM Sales_Analytics
WHERE Cust_ID = 42 OR Sale_Date = '2026-08-15';
-- OPTIMIZED Q3 (Uses idx_cust_status and idx_sale_date):
EXPLAIN SELECT Sale_ID, Cust_ID, Sale_Date, Amount FROM Sales_Analytics WHERE Cust_ID = 42
UNION
SELECT Sale_ID, Cust_ID, Sale_Date, Amount FROM Sales_Analytics WHERE Sale_Date = '2026-08-15';

-- [Query 4: Unindexed Filter + GROUP BY + ORDER BY vs Covering Index]
-- SLOW Q4 (Full scan + filesort when unindexed):
-- OPTIMIZED Q4 (Index-only scan via covering index idx_region_cat_status_amt):
EXPLAIN SELECT Category, COUNT(*) AS Txn_Count, SUM(Amount) AS Revenue
FROM Sales_Analytics
WHERE Region = 'North' AND Order_Status = 'Completed'
GROUP BY Category
ORDER BY Category;

-- [Query 5: IN Subquery with DISTINCT vs Grouped Filter]
-- SLOW Q5:
EXPLAIN SELECT DISTINCT Cust_ID FROM Sales_Analytics
WHERE Cust_ID IN (SELECT Cust_ID FROM Sales_Analytics WHERE Order_Status = 'Cancelled' AND Amount > 6500);
-- OPTIMIZED Q5 (Uses idx_cust_status range scan with GROUP BY):
EXPLAIN SELECT Cust_ID FROM Sales_Analytics
WHERE Order_Status = 'Cancelled' AND Amount > 6500
GROUP BY Cust_ID;
