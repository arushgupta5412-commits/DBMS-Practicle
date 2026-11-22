-- ============================================================================
-- EXPERIMENT 08: Banking Transactions, Savepoints & Concurrency Isolation Levels
-- Student Name : Arush Gupta
-- UID          : 25LBCS3097
-- Course       : DBMS Laboratory (MySQL 8.0+)
-- ============================================================================
-- Aim: To implement atomic banking fund transfers in MySQL using START
--      TRANSACTION (BEGIN), COMMIT, ROLLBACK, and SAVEPOINT for partial
--      failure recovery, and to demonstrate concurrency anomalies across
--      two concurrent database sessions under different SQL isolation levels.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Database Initialization & Safe Reset
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS Bharat_Banking;
USE Bharat_Banking;

DROP TABLE IF EXISTS Bank_Account;

CREATE TABLE Bank_Account (
    Acc_No INT PRIMARY KEY,
    Holder_Name VARCHAR(60) NOT NULL,
    Balance DECIMAL(12,2) NOT NULL CHECK (Balance >= 0)
);

INSERT INTO Bank_Account VALUES
(101, 'Aarav Sharma', 50000.00),
(102, 'Priya Nair', 30000.00),
(103, 'Rohan Deshmukh', 15000.00);

-- Initial State Display
SELECT '--- Initial Accounts State ---' AS Section_Header;
SELECT * FROM Bank_Account;

-- ============================================================================
-- PART 1: SAVEPOINT & PARTIAL FAILURE SIMULATION
-- Scenario: Aarav (101) transfers 10,000 to Priya (102) [Valid],
-- then attempts to transfer 25,000 to Rohan (103) [Simulated Policy Reversal].
-- ============================================================================
START TRANSACTION;

-- Step 1: Valid Transfer of 10,000 from Acc 101 to Acc 102
UPDATE Bank_Account SET Balance = Balance - 10000.00 WHERE Acc_No = 101;
UPDATE Bank_Account SET Balance = Balance + 10000.00 WHERE Acc_No = 102;

-- Create Savepoint after first successful transfer
SAVEPOINT after_first_transfer;

-- Step 2: Attempt second transfer of 25,000 to Acc 103 (Simulated Partial Failure / Reversal)
UPDATE Bank_Account SET Balance = Balance - 25000.00 WHERE Acc_No = 101;
UPDATE Bank_Account SET Balance = Balance + 25000.00 WHERE Acc_No = 103;

-- Rollback only Step 2 due to daily limit policy check failure
ROLLBACK TO SAVEPOINT after_first_transfer;

-- Commit the valid first transfer
COMMIT;

SELECT '--- Balances After Savepoint Rollback and Commit ---' AS Section_Header;
SELECT * FROM Bank_Account;

-- ============================================================================
-- PART 2: TWO-SESSION ISOLATION LEVEL & ANOMALY DEMO SCRIPTS
-- (To execute across two concurrent client windows/tabs)
-- ============================================================================

-- [ANOMALY 1: DIRTY READ under READ UNCOMMITTED]
-- Session B (Reader):
--   SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--   START TRANSACTION;
-- Session A (Writer):
--   START TRANSACTION;
--   UPDATE Bank_Account SET Balance = 99999.00 WHERE Acc_No = 101; -- Uncommitted!
-- Session B (Reader):
--   SELECT Acc_No, Balance FROM Bank_Account WHERE Acc_No = 101;  -- Reads 99999.00 (Dirty Read!)
-- Session A (Writer):
--   ROLLBACK;
-- Session B (Reader):
--   SELECT Acc_No, Balance FROM Bank_Account WHERE Acc_No = 101;  -- Back to 40000.00
--   COMMIT;

-- [ANOMALY 2: NON-REPEATABLE READ under READ COMMITTED]
-- Session B (Reader):
--   SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
--   START TRANSACTION;
--   SELECT Balance FROM Bank_Account WHERE Acc_No = 102; -- Reads 40000.00
-- Session A (Writer):
--   START TRANSACTION;
--   UPDATE Bank_Account SET Balance = 45000.00 WHERE Acc_No = 102;
--   COMMIT;
-- Session B (Same Transaction):
--   SELECT Balance FROM Bank_Account WHERE Acc_No = 102; -- Reads 45000.00 (Non-Repeatable Read!)
--   COMMIT;

-- [PREVENTION: REPEATABLE READ (Default)]
-- Session B (Reader):
--   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--   START TRANSACTION;
--   SELECT Balance FROM Bank_Account WHERE Acc_No = 102; -- Consistent snapshot at 40000.00
