# Experiment 8: Banking Transactions, Savepoints & Concurrency Isolation Levels

> **Student Name**: Arush Gupta  
> **UID**: 25LBCS3097  
> **Course**: DBMS Laboratory (MySQL 8.0+)

## 📌 Problem Statement
Implement banking-style transactions using `BEGIN`, `COMMIT`, `ROLLBACK`, and `SAVEPOINT`. Simulate partial failures. Demonstrate isolation levels and concurrency anomalies using two sessions.

---

## 1. Aim
To implement atomic banking fund transfers in MySQL using `START TRANSACTION` (`BEGIN`), `COMMIT`, `ROLLBACK`, and `SAVEPOINT` for partial failure recovery, and to demonstrate concurrency anomalies (Dirty Read, Non-Repeatable Read, Phantom Read) across two concurrent database sessions under different SQL isolation levels.

---

## 2. Objectives
1. Create a `Bank_Account` table and execute atomic fund transfers using `BEGIN`, `SAVEPOINT`, `ROLLBACK TO SAVEPOINT`, and `COMMIT`.
2. Simulate a multi-step batch transfer where a partial failure rolls back only the failed leg via `SAVEPOINT` while committing the valid transfer.
3. Demonstrate two-session concurrency behavior across `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, and `SERIALIZABLE`.

---

## 3. Two-Session Concurrency Timeline Diagram

```mermaid
sequenceDiagram
    participant S1 as Session A (Writer Transaction)
    participant DB as MySQL InnoDB Engine
    participant S2 as Session B (Reader Transaction)

    Note over S1,S2: Dirty Read Demo (Session B at READ UNCOMMITTED)
    S1->>DB: START TRANSACTION; UPDATE Bank_Account SET Balance = Balance - 10000 WHERE Acc_No = 101;
    S2->>DB: SELECT Balance FROM Bank_Account WHERE Acc_No = 101;
    DB-->>S2: Returns uncommitted Balance = 40000.00 (DIRTY READ!)
    S1->>DB: ROLLBACK; (Balance restored to 50000.00)
```

---

## 4. Execution Instructions

### Part 1: Automated Script (Savepoints & Partial Rollback)
```bash
mysql -u root -p < EXPERIMENT_08/experiment_08.sql
```

### Part 2: Interactive Two-Session Anomaly Testing
1. Open two separate terminal windows or MySQL Workbench query tabs.
2. In **Session B**, set the desired isolation level (e.g. `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;`).
3. Follow the scenario scripts provided in `experiment_08.sql` to witness Dirty Reads, Non-Repeatable Reads, and their prevention under `REPEATABLE READ`.

---

## 5. Output

### 5.1 Output After Savepoint Partial Rollback & `COMMIT`

| Acc_No | Holder_Name | Initial_Balance | Post-Transaction `Balance` | Outcome Explanation |
| ---: | :--- | ---: | ---: | :--- |
| 101 | Aarav Sharma | ₹50,000.00 | **₹40,000.00** | First transfer (`-₹10,000`) committed; second transfer (`-₹25,000`) rolled back to `SAVEPOINT`. |
| 102 | Priya Nair | ₹30,000.00 | **₹40,000.00** | Received `+₹10,000` prior to `SAVEPOINT after_first_transfer`. |
| 103 | Rohan Deshmukh | ₹15,000.00 | **₹15,000.00** | Unchanged because second leg was undone by `ROLLBACK TO SAVEPOINT`. |

### 5.2 Concurrency Anomalies & Isolation Level Comparison Output

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Observed Two-Session Behavior in MySQL InnoDB |
| :--- | :--- | :--- | :--- | :--- |
| **`READ UNCOMMITTED`** | **Occurs** | **Occurs** | **Occurs** | Session B reads Session A's uncommitted `99999.00` balance before Session A rolls back. |
| **`READ COMMITTED`** | Prevented | **Occurs** | **Occurs** | Session B only sees committed data, so two `SELECT` calls in one transaction return `40000.00` then `45000.00`. |
| **`REPEATABLE READ`** *(Default)* | Prevented | Prevented | Prevented (MVCC / Next-Key Locks) | Session B maintains a consistent MVCC read snapshot from its first read (`45000.00`). |
| **`SERIALIZABLE`** | Prevented | Prevented | Prevented | Converts plain `SELECT` into `SELECT ... FOR SHARE`, blocking concurrent `UPDATE`/`INSERT` until commit. |
