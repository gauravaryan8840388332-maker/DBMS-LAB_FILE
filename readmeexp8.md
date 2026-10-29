# Experiment 8: Transactions and Concurrency

## Aim
Demonstrate atomic banking transfers, rollback after partial failure, savepoint recovery, and transaction-isolation behavior using two MySQL sessions.

## 1. Create the Database and Account Table

```sql
CREATE DATABASE IF NOT EXISTS BankLab;
USE BankLab;

CREATE TABLE Account (
    account_id INT PRIMARY KEY,
    balance DECIMAL(12,2) NOT NULL CHECK (balance >= 0)
) ENGINE=InnoDB;

INSERT INTO Account VALUES (1,10000),(2,5000);
```

The initial total balance is 15000. In MySQL, enforced `CHECK` constraints require MySQL 8.0.16 or later.

## 2. Successful Transfer with COMMIT
A transaction transfers 1000 from account 1 to account 2. Both updates are committed together.

```sql
BEGIN;

SELECT *
FROM Account
WHERE account_id IN (1,2)
ORDER BY account_id
FOR UPDATE;

UPDATE Account
SET balance = balance - 1000
WHERE account_id = 1;

UPDATE Account
SET balance = balance + 1000
WHERE account_id = 2;

COMMIT;

SELECT * FROM Account;
```

Expected result after this transfer:

| account_id | balance |
|---:|---:|
| 1 | 9000.00 |
| 2 | 6000.00 |
| Total | 15000.00 |

`COMMIT` makes both changes durable together. `SELECT ... FOR UPDATE` is MySQL/InnoDB locking syntax. Lock accounts in a consistent order to reduce deadlock risk.

## 3. Rollback After a Partial Failure
The destination account ID 999 does not exist. The second update affects zero rows; this is not necessarily an SQL error, so the application must check affected-row counts and explicitly roll back.

```sql
BEGIN;

UPDATE Account
SET balance = balance - 700
WHERE account_id = 1;

UPDATE Account
SET balance = balance + 700
WHERE account_id = 999;

SELECT ROW_COUNT(); -- 0: destination account does not exist

ROLLBACK;

SELECT * FROM Account; -- balances return to 9000 and 6000
```

A full `ROLLBACK` cancels the transfer's first update too.

## 4. SAVEPOINT Recovery
The 500 transfer should remain, but a simulated optional fee of 50 should be undone.

```sql
BEGIN;

UPDATE Account
SET balance = balance - 500
WHERE account_id = 1;

UPDATE Account
SET balance = balance + 500
WHERE account_id = 2;

SAVEPOINT fee_step;

UPDATE Account
SET balance = balance - 50
WHERE account_id = 1;

-- Simulated fee-service rejection:
ROLLBACK TO SAVEPOINT fee_step;

RELEASE SAVEPOINT fee_step;
COMMIT;

SELECT * FROM Account; -- expected balances: 8500 and 6500
```

`ROLLBACK TO SAVEPOINT` reverses work after the savepoint without cancelling the transfer before it. `RELEASE SAVEPOINT` removes the savepoint marker.

## 5. Constraint Failure and Safe Error Handling

```sql
BEGIN;

UPDATE Account
SET balance = balance - 20000
WHERE account_id = 1;

-- Expected on MySQL with enforced CHECK:
-- CHECK constraint violation

ROLLBACK;
```

A statement error does not generally mean the entire transaction has automatically rolled back. Production code should roll back on exceptions, verify both account IDs and sufficient funds, and retry a deadlock-victim transaction safely.

## 6. Two-Session Isolation Demonstrations
Open two separate MySQL connections to `BankLab`. Finish both transactions and reset balances to 10000 and 5000 before each test. The following are illustrative MySQL/InnoDB schedules; they were not executed against a MySQL server in the supplied record.

### A. Dirty Read — READ UNCOMMITTED

Session A:

```sql
BEGIN;
UPDATE Account SET balance = 9000 WHERE account_id = 1;
-- Do not commit yet.
```

Session B:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN;
SELECT balance FROM Account WHERE account_id = 1; -- may show 9000
```

Then Session A:

```sql
ROLLBACK;
```

Session B:

```sql
SELECT balance FROM Account WHERE account_id = 1; -- 10000
COMMIT;
```

`READ UNCOMMITTED` may expose uncommitted values, so Session B can see a value that Session A later rolls back.

### B. Non-Repeatable Read — READ COMMITTED

Session B:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN;
SELECT balance FROM Account WHERE account_id = 1; -- 10000
```

Session A:

```sql
BEGIN;
UPDATE Account SET balance = 9000 WHERE account_id = 1;
COMMIT;
```

Session B:

```sql
SELECT balance FROM Account WHERE account_id = 1; -- 9000
COMMIT;
```

`READ COMMITTED` prevents dirty reads but allows successive reads in one transaction to see newly committed data.

### C. Repeatable Reads and Snapshot Behavior

Session B establishes a `REPEATABLE READ` snapshot:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT balance FROM Account WHERE account_id = 1; -- 10000
```

Session A updates and commits:

```sql
BEGIN;
UPDATE Account SET balance = 9000 WHERE account_id = 1;
COMMIT;
```

Session B reads again:

```sql
SELECT balance FROM Account WHERE account_id = 1; -- 10000 in the same snapshot
COMMIT;

SELECT balance FROM Account WHERE account_id = 1; -- 9000 in a new transaction
```

Plain snapshot reads and locking reads differ. Do not assume that every `REPEATABLE READ` operation sees a historical snapshot.

### D. Phantom Read Test

Reset the table to exactly two accounts. In Session B under `READ COMMITTED`:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN;
SELECT COUNT(*) FROM Account WHERE balance >= 5000; -- 2
```

In Session A:

```sql
INSERT INTO Account VALUES (3,7000);
COMMIT;
```

Back in Session B:

```sql
SELECT COUNT(*) FROM Account WHERE balance >= 5000; -- 3
COMMIT;
```

Repeat under `REPEATABLE READ` after deleting account 3. Two plain reads in Session B remain at 2 because they use the same snapshot.

### E. SERIALIZABLE Schedule

Session B:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
SELECT balance FROM Account WHERE account_id = 1;
```

Session A:

```sql
BEGIN;
UPDATE Account SET balance = 9000 WHERE account_id = 1;
-- This update may wait while B holds its read lock.
```

Session B:

```sql
COMMIT;
```

Session A's update can then complete:

```sql
COMMIT;
```

`SERIALIZABLE` prevents dirty reads and can block conflicting reads/writes to enforce a serializable order.

## 7. Lost Update and a Safer Pattern
Reset account 1 to 10000. Sessions A and B both read 10000 in separate `READ COMMITTED` transactions. A calculates and writes 9000, then commits. B uses its stale value to write 9500, then commits. The final balance is 9500, so A's deduction has been lost; the correct result after both deductions would be 8500.

Unsafe application-generated absolute writes:

```sql
-- Session A
UPDATE Account SET balance = 9000 WHERE account_id = 1;
COMMIT;

-- Session B, based on stale value
UPDATE Account SET balance = 9500 WHERE account_id = 1;
COMMIT;
```

Safer relative update:

```sql
BEGIN;

UPDATE Account
SET balance = balance - 1000
WHERE account_id = 1
  AND balance >= 1000;

SELECT ROW_COUNT(); -- require exactly 1

COMMIT;
```

Alternatively, use `SELECT ... FOR UPDATE` before calculating the new balance. The second session waits and reads the current committed balance after acquiring the lock.

## 8. Isolation-Level Summary

| Isolation level | Dirty reads | Repeated plain reads |
|---|---|---|
| READ UNCOMMITTED | Possible | May change |
| READ COMMITTED | Prevented | May change |
| REPEATABLE READ | Prevented | Stable snapshot for plain reads |
| SERIALIZABLE | Prevented | Read/write conflicts may block |

## Result and Conclusion
`COMMIT`, full `ROLLBACK`, and savepoint recovery demonstrate the intended transaction outcomes. The two-session schedules explain dirty reads, non-repeatable reads, phantom reads, lost updates, and blocking. The MySQL schedules are provided for execution; the supplied record locally verified transaction arithmetic but did not run these concurrency schedules against a MySQL server.

## Reference
- MySQL 8.4 Reference Manual — Transaction Isolation Levels: https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-isolation-levels.html
- MySQL Reference Manual — SAVEPOINT: https://dev.mysql.com/doc/refman/8.4/en/savepoint.html
