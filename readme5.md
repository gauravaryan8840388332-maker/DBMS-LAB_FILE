# DBMS Experiment – 5

## SQL Views, View Updatability and Recursive CTE

---

## 🎯 Aim

To create SQL views for department salary summaries and employee hierarchy, test the updatability of views, and implement a recursive Common Table Expression (CTE) to display employee reporting chains.

## 📌 Objectives

- Create a view that summarizes employee salary information department-wise.
- Create an employee hierarchy view using manager relationships.
- Test whether views are updatable and understand the conditions that affect view updates.
- Use a recursive CTE to display employee reporting chains.
- Verify the results using `SELECT` queries.

---

## 🗄️ Database Used

This experiment uses the `CompanyDB` database and the Employee–Department–Project schema. The `Employee` table must include a `manager_id` column that references `Employee(emp_id)`.

### Tables and Relationships

| Table | Purpose |
|---|---|
| `Department` | Stores department details |
| `Project` | Stores project details |
| `Employee` | Stores employee details, including department, project and manager |

**Important relationship:** `Employee.manager_id` refers to `Employee.emp_id`, creating a self-referencing relationship between employees and their managers.

---

# 💻 SQL Queries and Outputs

## 1. Department Salary Summary View

### Description

A view is a saved SQL query that behaves like a virtual table. This view summarizes the number of employees and salary statistics for each department.

### Query

```sql
CREATE OR REPLACE VIEW department_salary_summary AS
SELECT
    d.dept_id,
    d.dept_name,
    COUNT(e.emp_id) AS employee_count,
    AVG(e.salary) AS average_salary,
    MIN(e.salary) AS minimum_salary,
    MAX(e.salary) AS maximum_salary,
    SUM(e.salary) AS total_salary
FROM Department d
JOIN Employee e
    ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name;
```

### Verify the View

```sql
SELECT * FROM department_salary_summary;
```

### 📌 Output Screenshot

![Department Salary Summary View Output](images/01_department_salary_summary_output.png)

**Image file:** `01_department_salary_summary_output.png`

The view returns salary-summary information for each department represented in the result.

---

## 2. Employee Hierarchy View

### Description

This view displays each employee's department and the name of their immediate manager. A `LEFT JOIN` is used so employees without a manager can still appear in the view.

### Query

```sql
CREATE OR REPLACE VIEW employee_hierarchy AS
SELECT
    e.emp_id,
    e.emp_name,
    e.dept_id,
    d.dept_name,
    e.manager_id,
    m.emp_name AS manager_name,
    e.salary
FROM Employee e
JOIN Department d
    ON e.dept_id = d.dept_id
LEFT JOIN Employee m
    ON e.manager_id = m.emp_id;
```

### Verify the View

```sql
SELECT * FROM employee_hierarchy;
```

### 📌 Output Screenshot

![Employee Hierarchy View Output](images/02_employee_hierarchy_output.png)

**Image file:** `02_employee_hierarchy_output.png`

The view shows the immediate reporting relationship. Employees whose `manager_id` is `NULL` will have no manager name.

---

## 3. Test Updatability of Views

### Description

This experiment tests updates through the employee hierarchy view and the department salary summary view. Views containing joins, grouping or aggregate functions may not be directly updatable in the intended way.

### Query

```sql
UPDATE employee_hierarchy
SET salary = salary + 1000
WHERE emp_id = 6;

SELECT emp_id, emp_name, salary
FROM Employee
WHERE emp_id = 6;

UPDATE department_salary_summary
SET average_salary = average_salary + 1000
WHERE dept_id = 1;
```

### Explanation

- The update through `employee_hierarchy` may be rejected because the view contains joins. Updatability depends on the database engine and view definition.
- The update through `department_salary_summary` is not directly supported because the view contains `GROUP BY` and aggregate functions.
- To change an employee's salary, update the base `Employee` table directly, then query the view again to see the recalculated summary.

### Recommended Base-Table Update

> Run this only if you intend to change employee 6's salary.

```sql
UPDATE Employee
SET salary = salary + 1000
WHERE emp_id = 6;

SELECT emp_id, emp_name, salary
FROM Employee
WHERE emp_id = 6;
```

### 📌 Output Screenshot

![View Updatability Test Output](images/03_view_updatability_output.png)

**Image file:** `03_view_updatability_output.png`

Capture the successful or rejected update messages and the verification `SELECT` result.

---

## 4. Recursive CTE – Reporting Chain

### Description

A recursive CTE repeatedly follows the manager relationship to build employee reporting chains. The first query selects employees whose `manager_id` is `NULL`; the recursive part then finds employees reporting to those employees and continues down the hierarchy.

### Query

```sql
WITH RECURSIVE reporting_chain AS (
    SELECT
        e.emp_id,
        e.emp_name,
        e.manager_id,
        1 AS level,
        CAST(e.emp_name AS CHAR(500)) AS reporting_path
    FROM Employee e
    WHERE e.manager_id IS NULL

    UNION ALL

    SELECT
        e.emp_id,
        e.emp_name,
        e.manager_id,
        rc.level + 1,
        CONCAT(rc.reporting_path, ' -> ', e.emp_name)
    FROM Employee e
    JOIN reporting_chain rc
        ON e.manager_id = rc.emp_id
)
SELECT
    emp_id,
    emp_name,
    manager_id,
    level,
    reporting_path
FROM reporting_chain
ORDER BY reporting_path;
```

### 📌 Output Screenshot

![Recursive CTE Reporting Chain Output](images/04_recursive_cte_output.png)

**Image file:** `04_recursive_cte_output.png`

The result displays each employee's hierarchy level and the path from the top-level employee to that employee. The query assumes that the manager relationships are correctly populated and do not contain cycles.

---

# 📚 Concepts Demonstrated

1. Creating and querying SQL views
2. Department-wise aggregate summaries
3. Self-referencing employee-manager relationships
4. View updatability
5. `GROUP BY` and aggregate functions
6. `WITH RECURSIVE` CTE
7. Reporting levels and hierarchy paths

---

# 📸 Output Screenshot Checklist

Save the screenshots inside the `images` folder with these exact filenames:

| No. | Experiment Task | Image Filename |
|---:|---|---|
| 1 | Department Salary Summary View | `01_department_salary_summary_output.png` |
| 2 | Employee Hierarchy View | `02_employee_hierarchy_output.png` |
| 3 | View Updatability Test | `03_view_updatability_output.png` |
| 4 | Recursive CTE – Reporting Chain | `04_recursive_cte_output.png` |

The image links above use relative paths, so GitHub will display the screenshots once the files are uploaded with matching names.

---

## 📁 Recommended Folder Structure

```text
DBMS-LAB_FILE/
└── Experiment-5/
    ├── README.md
    ├── exp05.sql
    └── images/
        ├── 01_department_salary_summary_output.png
        ├── 02_employee_hierarchy_output.png
        ├── 03_view_updatability_output.png
        └── 04_recursive_cte_output.png
```

---

## ✅ Result

Views were defined for department salary summaries and employee hierarchy. View update behavior was tested, and a recursive CTE was written to display employee reporting chains.

## 📝 Conclusion

SQL views provide reusable logical representations of data, while recursive CTEs can traverse self-referencing employee relationships to display hierarchical reporting structures. Testing view updatability also helps explain why views containing joins or aggregate operations may not support direct updates.
