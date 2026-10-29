# Experiment 10: Analyze and Optimize Five Slow Queries

## Aim
Create 10,000 order records, analyze five queries, optimize them using indexes and equivalent query rewrites, and compare execution plans and query times.

## 1. Create the Benchmark Tables and Data
This experiment uses the `Numbers` table generated in Experiment 9. Run that setup first. Amounts are stored as integer cents to avoid floating-point comparison errors. Generated email values are lowercase, and every customer has ten orders.

```sql
USE PerfLab;

CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(40)
);

INSERT INTO Customers
SELECT n, CONCAT('Customer ',n)
FROM Numbers
WHERE n <= 1000;

CREATE TABLE OrdersBench (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    status VARCHAR(12),
    amount_cents INT,
    email VARCHAR(80)
) ENGINE=InnoDB;

INSERT INTO OrdersBench
SELECT
    n,
    1 + MOD(n,1000),
    DATE_ADD('2026-01-01', INTERVAL MOD(n*13,365) DAY),
    ELT(1+MOD(n,3),'PAID','PENDING','CANCELLED'),
    1000 + MOD(n*97,99000),
    CONCAT('user',MOD(n,1000),'@example.com')
FROM Numbers;

SELECT COUNT(*) FROM OrdersBench; -- 10000
SELECT COUNT(*) FROM Customers;   -- 1000
```

## 2. Benchmark Procedure
For each query pair:
1. Capture the baseline execution plan.
2. Execute a warm-up, then run the baseline seven times, fully fetching results.
3. Create only the index specified for that query and update statistics.
4. Run the optimized query and capture its plan and timings.
5. Compare the full result sets to ensure equivalent results.
6. Drop the index before testing the next independent query pair.

MySQL commands:

```sql
ANALYZE TABLE OrdersBench;
EXPLAIN FORMAT=TRADITIONAL SELECT ...;
EXPLAIN ANALYZE SELECT ...;
```

The measured timing and plan transcripts in the supplied record were produced using Python 3.12.14 and SQLite 3.53.1 in memory on Linux, not MySQL. MySQL syntax and `EXPLAIN` commands are provided for running the experiment in MySQL. The local timing method includes result fetching and Python call overhead, excludes setup/index creation, and does not measure cold-disk behavior.

## Q1 — Make the Date Predicate Searchable
### Before: function on the date column

```sql
SELECT COUNT(*)
FROM OrdersBench
WHERE strftime('%Y-%m', order_date) = '2026-03';
```

In the MySQL version, the baseline uses `DATE_FORMAT(order_date,'%Y-%m')='2026-03'`. Applying a function to the column makes a straightforward date-range lookup harder.

### Index and optimized query

```sql
CREATE INDEX idx_date ON OrdersBench(order_date);

SELECT COUNT(*)
FROM OrdersBench
WHERE order_date >= '2026-03-01'
  AND order_date <  '2026-04-01';
```

The half-open range is equivalent for March and also handles timestamp columns safely when the end boundary is exclusive.

Local plan before:

```text
SCAN OrdersBench
```

Local plan after:

```text
SEARCH OrdersBench USING COVERING INDEX idx_date
(order_date>? AND order_date<?)
```

| Metric | Result |
|---|---:|
| Median before | 2.2899 ms |
| Median after | 0.0199 ms |
| Speedup | 114.85× |
| Returned result rows | 1 |

Full results matched.

## Q2 — Composite Index for Customer and Amount
The query selects orders for customer 42 with an amount of at least 50000 cents, ordered by `order_id`.

```sql
SELECT order_id, amount_cents
FROM OrdersBench
WHERE customer_id = 42
  AND amount_cents >= 50000
ORDER BY order_id;
```

Create the composite index and run the same query:

```sql
CREATE INDEX idx_customer_amount
ON OrdersBench(customer_id, amount_cents);

SELECT order_id, amount_cents
FROM OrdersBench
WHERE customer_id = 42
  AND amount_cents >= 50000
ORDER BY order_id;
```

The index supports equality on `customer_id` followed by a range on `amount_cents`. A small output sort remains because `order_id` is not the next index ordering column.

Local plan before:

```text
SCAN OrdersBench
```

Local plan after:

```text
SEARCH OrdersBench USING COVERING INDEX idx_customer_amount
(customer_id=? AND amount_cents>?)
USE TEMP B-TREE FOR ORDER BY
```

| Metric | Result |
|---|---:|
| Median before | 0.3505 ms |
| Median after | 0.0042 ms |
| Speedup | 84.32× |
| Rows returned | 8 |

Sample output:

| order_id | amount_cents |
|---:|---:|
| 2041 | 99977 |
| 3041 | 97977 |
| 4041 | 95977 |
| 5041 | 93977 |
| 6041 | 91977 |

## Q3 — Index for Filter, Sort, and LIMIT
The query selects the 20 latest paid orders.

```sql
SELECT order_id, order_date
FROM OrdersBench
WHERE status = 'PAID'
ORDER BY order_date DESC, order_id DESC
LIMIT 20;
```

Create an index matching the equality predicate and descending order:

```sql
CREATE INDEX idx_status_date
ON OrdersBench(status, order_date DESC, order_id DESC);

SELECT order_id, order_date
FROM OrdersBench
WHERE status = 'PAID'
ORDER BY order_date DESC, order_id DESC
LIMIT 20;
```

The index follows the status predicate and descending date/order tie-break. `LIMIT` can stop after the first 20 matching entries.

Local plan before:

```text
SCAN OrdersBench
USE TEMP B-TREE FOR ORDER BY
```

Local plan after:

```text
SEARCH OrdersBench USING COVERING INDEX idx_status_date (status=?)
```

| Metric | Result |
|---|---:|
| Median before | 0.5684 ms |
| Median after | 0.0070 ms |
| Speedup | 81.54× |
| Rows returned | 20 |

Sample output:

| order_id | order_date |
|---:|---|
| 9153 | 2026-12-31 |
| 8058 | 2026-12-31 |
| 6963 | 2026-12-31 |
| 5868 | 2026-12-31 |
| 4773 | 2026-12-31 |

## Q4 — Replace Repeated Correlated Aggregation
### Before: correlated scalar subquery

```sql
SELECT
    c.customer_id,
    (SELECT SUM(o.amount_cents)
     FROM OrdersBench o
     WHERE o.customer_id = c.customer_id) AS total
FROM Customers c
ORDER BY c.customer_id;
```

The correlated subquery can repeatedly scan the orders table for each customer.

### Index and rewritten query

```sql
CREATE INDEX idx_customer_amount
ON OrdersBench(customer_id, amount_cents);

SELECT c.customer_id, a.total
FROM Customers c
LEFT JOIN (
    SELECT customer_id, SUM(amount_cents) AS total
    FROM OrdersBench
    GROUP BY customer_id
) a ON a.customer_id = c.customer_id
ORDER BY c.customer_id;
```

Pre-aggregation computes each customer's total once. `LEFT JOIN` retains customers without orders, with a `NULL` total, preserving scalar `SUM` semantics. In the local benchmark, automatic SQLite indexes were disabled, so the materialized join still scanned its derived result.

Local plan before:

```text
SCAN c
CORRELATED SCALAR SUBQUERY
1 SCAN o
```

Local plan after:

```text
MATERIALIZE a
SCAN OrdersBench USING COVERING INDEX idx_customer_amount
SCAN c
SCAN a LEFT-JOIN
```

| Metric | Result |
|---|---:|
| Median before | 303.5859 ms |
| Median after | 28.3631 ms |
| Speedup | 10.70× |
| Rows returned | 1000 |

Sample output:

| customer_id | total |
|---:|---:|
| 1 | 890000 |
| 2 | 811970 |
| 3 | 812940 |
| 4 | 813910 |
| 5 | 814880 |

## Q5 — Remove a Redundant Function from Email Search
The generated email values are already lowercase, so `LOWER(email)` is unnecessary for this fixture. For arbitrary mixed-case data, normalize values on write or use an appropriate functional index/collation instead.

### Before

```sql
SELECT order_id
FROM OrdersBench
WHERE lower(email) = 'user41@example.com'
ORDER BY order_id;
```

### Index and optimized query

```sql
CREATE INDEX idx_email ON OrdersBench(email);

SELECT order_id
FROM OrdersBench
WHERE email = 'user41@example.com'
ORDER BY order_id;
```

Local plan before:

```text
SCAN OrdersBench
```

Local plan after:

```text
SEARCH OrdersBench USING COVERING INDEX idx_email (email=?)
```

| Metric | Result |
|---|---:|
| Median before | 0.9010 ms |
| Median after | 0.0030 ms |
| Speedup | 297.94× |
| Rows returned | 10 |

Sample output order IDs: `41, 1041, 2041, 3041, 4041`.

## 3. Overall Performance Comparison

| Query | Before (ms) | After (ms) | Speedup |
|---|---:|---:|---:|
| Q1 — Date range | 2.2899 | 0.0199 | 114.85× |
| Q2 — Customer and amount | 0.3505 | 0.0042 | 84.32× |
| Q3 — Paid orders by date | 0.5684 | 0.0070 | 81.54× |
| Q4 — Customer totals | 303.5859 | 28.3631 | 10.70× |
| Q5 — Email lookup | 0.9010 | 0.0030 | 297.94× |

These are actual local SQLite measurements, not estimated MySQL runtimes. Q4 remains slower than the other optimized queries because it aggregates all orders and joins a materialized relation.

## 4. Reproducibility: Timing and Plan Inspection
The report used one warm-up followed by seven executions, fetched all rows each time, and reported median, minimum, and maximum elapsed milliseconds.

```python
import time
import statistics

def benchmark(connection, sql):
    connection.execute(sql).fetchall()  # warm-up
    samples = []
    for _ in range(7):
        start = time.perf_counter_ns()
        rows = connection.execute(sql).fetchall()
        samples.append((time.perf_counter_ns() - start) / 1e6)
    return statistics.median(samples), min(samples), max(samples)
```

SQLite plan inspection:

```python
connection.execute("EXPLAIN QUERY PLAN " + sql).fetchall()
```

MySQL plan inspection:

```sql
EXPLAIN FORMAT=TRADITIONAL SELECT ...;
EXPLAIN ANALYZE SELECT ...;
```

SQLite `DATE` values were ISO text. The MySQL `DATE_FORMAT` predicate in Q1 was translated to `strftime`; the other benchmark `SELECT` statements were unchanged. The railway and order generators used the formulas printed in Experiments 9 and 10. Timing includes result fetching and Python call overhead, excludes setup and index creation, and does not measure cold-disk behavior.

## Result and Conclusion
Five query pairs produced equivalent results. Indexing reduced full table scans, made predicates searchable, supported sorting where possible, and reduced repeated aggregation. The greatest measured speedup was Q5 at 297.94×; Q4 had the smallest speedup at 10.70× because it aggregates the entire orders relation and joins the materialized result. Query optimization should be validated with actual execution plans and timings rather than assuming an index always helps.

## References
- MySQL 8.4 Reference Manual — EXPLAIN Statement: https://dev.mysql.com/doc/refman/8.4/en/explain.html
- MySQL 8.4 Reference Manual — Transaction Isolation Levels: https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-isolation-levels.html
- MySQL Reference Manual — SAVEPOINT: https://dev.mysql.com/doc/refman/8.4/en/savepoint.html
