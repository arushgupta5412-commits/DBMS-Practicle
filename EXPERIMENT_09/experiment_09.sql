-- ============================================================================
-- EXPERIMENT 09: Railway Booking Schema (5,000+ Rows) & Index Performance Benchmarking
-- Student Name : Arush Gupta
-- UID          : 25LBCS3097
-- Course       : DBMS Laboratory (MySQL 8.0+)
-- ============================================================================
-- Aim: To create and populate an Indian Railway_Booking table with 5,000
--      synthetic PNR records in MySQL, benchmark search and aggregation query
--      latency before and after adding single-column and composite B-Tree
--      indexes, and compare execution plans using EXPLAIN.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Database Initialization & Safe Reset
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS IRCTC_Benchmark;
USE IRCTC_Benchmark;

DROP TABLE IF EXISTS Railway_Booking;

CREATE TABLE Railway_Booking (
    Booking_ID INT PRIMARY KEY,
    PNR_No CHAR(10) NOT NULL UNIQUE,
    Passenger_Name VARCHAR(60) NOT NULL,
    Train_No INT NOT NULL,
    Source_Stn CHAR(4) NOT NULL,
    Dest_Stn CHAR(4) NOT NULL,
    Journey_Date DATE NOT NULL,
    Coach_Class ENUM('1A', '2A', '3A', 'SL', 'CC') NOT NULL,
    Booking_Status ENUM('CNF', 'RAC', 'WL') NOT NULL,
    Fare DECIMAL(8,2) NOT NULL
);

-- ----------------------------------------------------------------------------
-- STEP 2: Populate 5,000 rows using a Recursive CTE Generator
-- ----------------------------------------------------------------------------
SET SESSION cte_max_recursion_depth = 6000;

INSERT INTO Railway_Booking
WITH RECURSIVE Seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Seq WHERE n < 5000
)
SELECT
    n AS Booking_ID,
    LPAD(1000000000 + n, 10, '0') AS PNR_No,
    CONCAT('Passenger_', n) AS Passenger_Name,
    ELT((n % 10) + 1, 12951, 12002, 12301, 12259, 12430, 12627, 12801, 22436, 12953, 12137) AS Train_No,
    ELT((n % 5) + 1, 'NDLS', 'MMCT', 'HWH', 'MAS', 'SBC') AS Source_Stn,
    ELT((n % 5) + 1, 'LKO', 'BPL', 'PNBE', 'NGP', 'HYB') AS Dest_Stn,
    DATE_ADD('2026-11-01', INTERVAL (n % 60) DAY) AS Journey_Date,
    ELT((n % 5) + 1, '1A', '2A', '3A', 'SL', 'CC') AS Coach_Class,
    ELT((n % 3) + 1, 'CNF', 'RAC', 'WL') AS Booking_Status,
    ROUND(500 + (n % 2500) * 1.25, 2) AS Fare
FROM Seq;

-- ----------------------------------------------------------------------------
-- PHASE 1: BENCHMARK BEFORE INDEXING (Full Table Scan)
-- ----------------------------------------------------------------------------
SELECT '--- Phase 1: Query Execution Plan WITHOUT Indexes ---' AS Benchmark_Phase;
EXPLAIN SELECT Booking_ID, PNR_No, Passenger_Name, Coach_Class, Fare
FROM Railway_Booking
WHERE Train_No = 12951
  AND Journey_Date = '2026-11-15'
  AND Booking_Status = 'CNF';

-- ----------------------------------------------------------------------------
-- PHASE 2: CREATE SINGLE-COLUMN INDEX & BENCHMARK
-- ----------------------------------------------------------------------------
CREATE INDEX idx_train_no ON Railway_Booking(Train_No);

SELECT '--- Phase 2: Query Execution Plan WITH Single Index (idx_train_no) ---' AS Benchmark_Phase;
EXPLAIN SELECT Booking_ID, PNR_No, Passenger_Name, Coach_Class, Fare
FROM Railway_Booking
WHERE Train_No = 12951
  AND Journey_Date = '2026-11-15'
  AND Booking_Status = 'CNF';

-- ----------------------------------------------------------------------------
-- PHASE 3: CREATE COMPOSITE INDEX & BENCHMARK
-- ----------------------------------------------------------------------------
CREATE INDEX idx_train_date_status
ON Railway_Booking(Train_No, Journey_Date, Booking_Status);

SELECT '--- Phase 3: Query Execution Plan WITH Composite Index (idx_train_date_status) ---' AS Benchmark_Phase;
EXPLAIN SELECT Booking_ID, PNR_No, Passenger_Name, Coach_Class, Fare
FROM Railway_Booking
WHERE Train_No = 12951
  AND Journey_Date = '2026-11-15'
  AND Booking_Status = 'CNF';

-- Verification Result Sample
SELECT '--- Sample Matching Records ---' AS Benchmark_Phase;
SELECT Booking_ID, PNR_No, Passenger_Name, Coach_Class, Fare
FROM Railway_Booking
WHERE Train_No = 12951
  AND Journey_Date = '2026-11-15'
  AND Booking_Status = 'CNF'
LIMIT 5;
