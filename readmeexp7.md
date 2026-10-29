# Experiment 7: Normalization and Verification

## Aim
Identify functional dependencies in a denormalized sales relation and normalize it from Unnormalized Form (UNF) through First Normal Form (1NF), Second Normal Form (2NF), Third Normal Form (3NF), and Boyce–Codd Normal Form (BCNF). Verify lossless reconstruction and dependency preservation.

## Assumptions and Functional Dependencies
- Each order has one customer and one order date.
- A product appears at most once per order.
- A product's category is stable.
- `unit_price` is the historical sale price and can vary between orders.
- All attributes in the supplied fixture are non-null.

Functional dependencies:

```text
order_id -> order_date, customer_id
customer_id -> customer_name, city
product_id -> product_name, category_id
category_id -> category_name
(order_id, product_id) -> qty, unit_price
```

The candidate key is `(order_id, product_id)`. Its closure contains all attributes. Neither `order_id` nor `product_id` alone determines both quantity and historical sale price.

## 1. UNF to 1NF
In UNF, an order may store multiple products in one repeating field. Example: order 101 for Asha from Delhi contains `[(10, Keyboard, 2, 800), (20, Monitor, 1, 9000)]`. Convert the repeating group into one row per order-product combination. This makes each field atomic, although customer and product details are still repeated.

```sql
CREATE TABLE Sales1NF (
    order_id INT,
    order_date DATE,
    customer_id INT,
    customer_name VARCHAR(40),
    city VARCHAR(30),
    product_id INT,
    product_name VARCHAR(40),
    category_id INT,
    category_name VARCHAR(30),
    qty INT,
    unit_price DECIMAL(10,2),
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO Sales1NF VALUES
(101,'2026-01-10',1,'Asha','Delhi',10,'Keyboard',1,'Accessories',2,800),
(101,'2026-01-10',1,'Asha','Delhi',20,'Monitor',2,'Displays',1,9000),
(102,'2026-01-11',2,'Ravi','Pune',10,'Keyboard',1,'Accessories',1,750),
(103,'2026-01-12',1,'Asha','Delhi',30,'Mouse',1,'Accessories',3,400),
(104,'2026-01-13',3,'Neha','Jaipur',20,'Monitor',2,'Displays',2,8800),
(104,'2026-01-13',3,'Neha','Jaipur',30,'Mouse',1,'Accessories',1,380);
```

## 2. 1NF to 2NF
The key is composite. Remove partial dependencies on only part of that key by separating order-level data, product-level data, and order-line data:

- `OrderHeader(order_id, order_date, customer_id, customer_name, city)`
- `ProductInfo(product_id, product_name, category_id, category_name)`
- `OrderLine(order_id, product_id, qty, unit_price)`

After this decomposition, each non-key attribute in the order-line relation depends on the whole composite key.

## 3. 2NF to 3NF
Remove transitive dependencies:
- `customer_id -> customer_name, city` is moved to `Customer`.
- `category_id -> category_name` is moved to `Category`.

The normalized schema uses five relations: `Customer`, `Category`, `Product`, `SalesOrder`, and `OrderLine`.

```sql
CREATE TABLE Customer (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(40) NOT NULL,
    city VARCHAR(30) NOT NULL
);

CREATE TABLE Category (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(30) NOT NULL
);

CREATE TABLE Product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(40) NOT NULL,
    category_id INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Category(category_id)
);

CREATE TABLE SalesOrder (
    order_id INT PRIMARY KEY,
    order_date DATE NOT NULL,
    customer_id INT NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

CREATE TABLE OrderLine (
    order_id INT,
    product_id INT,
    qty INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES SalesOrder(order_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id)
);
```

## 4. BCNF
The five resulting relations are already in BCNF under the stated dependencies: every non-trivial determinant in each relation is a candidate key. No further decomposition is required for this schema. Although 3NF does not always imply BCNF, it does here.

## 5. Populate the Normalized Tables and Reconstruct the Original Relation

```sql
INSERT INTO Customer
SELECT DISTINCT customer_id, customer_name, city
FROM Sales1NF;

INSERT INTO Category
SELECT DISTINCT category_id, category_name
FROM Sales1NF;

INSERT INTO Product
SELECT DISTINCT product_id, product_name, category_id
FROM Sales1NF;

INSERT INTO SalesOrder
SELECT DISTINCT order_id, order_date, customer_id
FROM Sales1NF;

INSERT INTO OrderLine
SELECT order_id, product_id, qty, unit_price
FROM Sales1NF;

CREATE VIEW Reconstructed AS
SELECT
    o.order_id, o.order_date,
    c.customer_id, c.customer_name, c.city,
    p.product_id, p.product_name,
    k.category_id, k.category_name,
    l.qty, l.unit_price
FROM OrderLine l
JOIN SalesOrder o ON o.order_id = l.order_id
JOIN Customer c ON c.customer_id = o.customer_id
JOIN Product p ON p.product_id = l.product_id
JOIN Category k ON k.category_id = p.category_id;
```

## 6. Verify Reconstruction
Compare row counts, then compare all columns in both directions. Equal counts alone do not prove equality.

```sql
SELECT COUNT(*) AS source_rows FROM Sales1NF;
SELECT COUNT(*) AS reconstructed_rows FROM Reconstructed;

SELECT COUNT(*) AS missing_rows
FROM Sales1NF s
WHERE NOT EXISTS (
    SELECT 1
    FROM Reconstructed r
    WHERE r.order_id = s.order_id
      AND r.product_id = s.product_id
      AND r.order_date = s.order_date
      AND r.customer_id = s.customer_id
      AND r.customer_name = s.customer_name
      AND r.city = s.city
      AND r.product_name = s.product_name
      AND r.category_id = s.category_id
      AND r.category_name = s.category_name
      AND r.qty = s.qty
      AND r.unit_price = s.unit_price
);
```

Repeat the anti-join with `Sales1NF` and `Reconstructed` exchanged to test for extra rows. The primary key prevents duplicate order-product rows.

### Verified fixture results

| Check | Result |
|---|---:|
| Input rows | 6 |
| Reconstructed rows | 6 |
| Missing rows | 0 |
| Extra rows | 0 |
| `SUM(qty * unit_price)` | 30530 |

The local check compared the full eleven-column rows in both directions. Both relations matched exactly, including historical prices.

## 7. Dependency Preservation
Each original functional dependency can be enforced in one component:
- `order_id` dependencies in `SalesOrder`
- `customer_id` dependencies in `Customer`
- `product_id` dependencies in `Product`
- `category_id` dependency in `Category`
- `(order_id, product_id)` dependencies in `OrderLine`

The following queries detect violations in the current fixture; all return zero rows:

```sql
SELECT order_id
FROM Sales1NF
GROUP BY order_id
HAVING COUNT(DISTINCT order_date) > 1
    OR COUNT(DISTINCT customer_id) > 1;

SELECT customer_id
FROM Sales1NF
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1
    OR COUNT(DISTINCT city) > 1;

SELECT product_id
FROM Sales1NF
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
    OR COUNT(DISTINCT category_id) > 1;

SELECT category_id
FROM Sales1NF
GROUP BY category_id
HAVING COUNT(DISTINCT category_name) > 1;

SELECT order_id, product_id
FROM Sales1NF
GROUP BY order_id, product_id
HAVING COUNT(DISTINCT qty) > 1
    OR COUNT(DISTINCT unit_price) > 1;
```

These checks test the current data. The schema and dependency argument establish preservation for valid future instances.

## 8. Lossless-Join Proof and Anomalies Removed
At each decomposition, the common attributes determine one component: `order_id` determines order data, `product_id` determines product data, `customer_id` determines customer data, and `category_id` determines category data. Each binary split satisfies the lossless-join criterion. Foreign keys prevent orphan rows.

The decomposition removes common anomalies:
- Updating a customer's city requires changing one `Customer` row.
- A category can be inserted before any sale uses it.
- Deleting the last sale of a product does not delete the product information.

## Result and Conclusion
The six-row fixture reconstructs exactly, including historical sale prices. The five-table design is lossless and dependency-preserving and satisfies BCNF under the stated business rules.
