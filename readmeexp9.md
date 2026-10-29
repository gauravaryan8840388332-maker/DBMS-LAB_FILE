# Experiment 9: Railway Booking Indexes and Query Performance

## Aim
Generate 5,000 railway booking records and compare query performance and execution plans with no secondary index, a single-column index, and a composite index.

## 1. Create the Database and Generate Deterministic Data
Run the setup once in an empty schema. The `Digit` and `Numbers` tables generate the integers used to create 5,000 reproducible bookings.

```sql
CREATE DATABASE IF NOT EXISTS PerfLab;
USE PerfLab;

CREATE TABLE Digit (d INT PRIMARY KEY);
INSERT INTO Digit VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

CREATE TABLE Numbers (n INT PRIMARY KEY);
INSERT INTO Numbers
SELECT 1 + a.d + 10*b.d + 100*c.d + 1000*d.d
FROM Digit a
CROSS JOIN Digit b
CROSS JOIN Digit c
CROSS JOIN Digit d;

CREATE TABLE RailwayBooking (
    booking_id INT PRIMARY KEY,
    train_no INT,
    journey_date DATE,
    passenger_name VARCHAR(40),
    source VARCHAR(20),
    destination VARCHAR(20),
    status VARCHAR(12),
    fare INT
) ENGINE=InnoDB;

INSERT INTO RailwayBooking
SELECT
    n,
    12000 + MOD(n,50),
    DATE_ADD('2026-01-01', INTERVAL MOD(n*17,180) DAY),
    CONCAT('Passenger ',n),
    ELT(1+MOD(n,5),'Delhi','Mumbai','Kolkata','Chennai','Pune'),
    ELT(1+MOD(n,5),'Jaipur','Surat','Patna','Madurai','Nagpur'),
    ELT(1+MOD(n,3),'CONFIRMED','WAITLIST','CANCELLED'),
    300 + MOD(n,1200)
FROM Numbers
WHERE n <= 5000;

SELECT COUNT(*) FROM RailwayBooking; -- 5000
```

The local benchmark used the same deterministic formulas, with Python date arithmetic instead of MySQL's `DATE_ADD`.

## 2. Query to Benchmark
Find bookings for train 12007 during March 2026 and order them by journey date and booking ID.

```sql
SELECT booking_id, journey_date, fare
FROM RailwayBooking
WHERE train_no = 12007
  AND journey_date >= '2026-03-01'
  AND journey_date < '2026-04-01'
ORDER BY journey_date, booking_id;
```

Inspect the initial execution plan:

```sql
EXPLAIN FORMAT=TRADITIONAL
SELECT booking_id, journey_date, fare
FROM RailwayBooking
WHERE train_no = 12007
  AND journey_date >= '2026-03-01'
  AND journey_date < '2026-04-01'
ORDER BY journey_date, booking_id;
```

For MySQL timing and actual plan information, run `EXPLAIN ANALYZE` with the same `SELECT` on a supported MySQL version.

## 3. Configuration A — No Secondary Index
The table has only its primary key on `booking_id`. The local SQLite plan was:

```text
SCAN RailwayBooking
USE TEMP B-TREE FOR ORDER BY
```

The engine scans the table and uses a temporary sorting structure for the requested order.

## 4. Configuration B — Single-Column Index
Create an index on `train_no`, update statistics, and rerun the query and plan.

```sql
CREATE INDEX idx_train ON RailwayBooking(train_no);
ANALYZE TABLE RailwayBooking;
```

Local SQLite plan:

```text
SEARCH RailwayBooking USING INDEX idx_train (train_no=?)
USE TEMP B-TREE FOR ORDER BY
```

The index narrows the candidates to the selected train, but a separate sort remains because the index does not provide the full date/booking ordering.

Drop this index before testing the next configuration:

```sql
DROP INDEX idx_train ON RailwayBooking;
```

## 5. Configuration C — Composite Index
Create a composite index with the equality-filter column first, followed by the date range and ordering tie-breaker.

```sql
CREATE INDEX idx_train_date
ON RailwayBooking(train_no, journey_date, booking_id);

ANALYZE TABLE RailwayBooking;
```

Rerun the query and `EXPLAIN`. Local SQLite plan:

```text
SEARCH RailwayBooking USING INDEX idx_train_date
(train_no=? AND journey_date>? AND journey_date<?)
```

The composite index supports the train equality condition, journey-date range, and requested ordering. The plan no longer reports the temporary sort seen in the first two configurations. The index is not covering for `fare`, because `fare` is not part of the index.

MySQL may change from `ALL` table access to `ref` or `range` access, but the optimizer determines the actual plan for the environment and statistics.

## 6. Measured Local Results

| Configuration | Median time (ms) | Observed range (ms) | Rows returned |
|---|---:|---:|---:|
| No secondary index | 0.1364 | 0.1352–0.1931 | 22 |
| Single-column index | 0.0263 | 0.0240–0.0303 | 22 |
| Composite index | 0.0158 | 0.0126–0.0903 | 22 |

Sample of the first five of the 22 result rows:

| booking_id | journey_date | fare |
|---:|---|---:|
| 607 | 2026-03-01 | 907 |
| 1507 | 2026-03-01 | 607 |
| 2407 | 2026-03-01 | 307 |
| 3307 | 2026-03-01 | 1207 |
| 4207 | 2026-03-01 | 907 |

All three configurations returned the same 22 rows. In this local run, the composite index was 8.62 times faster than the no-secondary-index baseline.

## 7. Benchmark Method and Limitations
The report's measured plans and times were collected using SQLite 3.53.1 in memory on Linux, with Python 3.12.14. They are not MySQL timings. The benchmark used deterministic data, one warm-up and seven fully fetched executions, reporting median elapsed wall-clock time. Index creation was excluded from the timed query. Automatic SQLite indexes were disabled. Results were checked for equality. Small in-memory measurements are environment-dependent and do not measure cold-disk behavior.

## Result
All three configurations returned identical results. The composite index produced the fastest median time in the supplied local benchmark.

## Conclusion
An index on `train_no` narrows the candidate rows but still requires sorting. Adding `journey_date` and `booking_id` supports filtering and ordered retrieval together. Indexes consume storage and add insert/update costs; these costs were not included in the read-only benchmark. Validate the plan and performance in the actual MySQL environment before drawing conclusions about production behavior.
