# DBMS Experiment – 3

## Employee–Department–Project Relational Database

---

## Aim

To create an Employee–Department–Project relational database, insert at least 30 employees across 5 departments and 8 projects, and demonstrate SQL queries using Selection, Projection, Aggregate Functions, GROUP BY, HAVING, CASE expressions, and ORDER BY.

---

## Database Structure

The database consists of three tables:

### 1. Department

The Department table stores information about different departments.

**Attributes:**

- Department ID
- Department Name

**Departments:**

- IT
- HR
- Finance
- Marketing
- Operations

### 2. Project

The Project table stores information about different projects.

**Attributes:**

- Project ID
- Project Name
- Budget
- Department ID

**Projects:**

- Cloud Migration
- AI Analytics
- Recruitment Portal
- Financial Dashboard
- Digital Campaign
- Supply Chain System
- Mobile Application
- Employee Wellness

### 3. Employee

The Employee table stores information about employees.

**Attributes:**

- Employee ID
- Employee Name
- Salary
- Hire Date
- Department ID
- Project ID

The database contains 30 employees distributed across the five departments.

---

# SQL Queries and Outputs

## 1. Selection

### Description

Selection is used to retrieve records that satisfy a particular condition.

In this experiment, employees whose salary is greater than 70,000 are displayed.

### Query

```sql
SELECT *
FROM Employee
WHERE salary > 70000;
📌 OUTPUT

Image Name: 01_selection_output.png

2. Projection
Description

Projection is used to display only the required columns from a table.

In this experiment, employee names and salaries are displayed.

Query
SELECT emp_name, salary
FROM Employee;
📌 OUTPUT

Image Name: 02_projection_output.png

3. Aggregate Functions
Description

Aggregate functions are used to perform calculations on employee data.

The following aggregate functions are demonstrated:

COUNT() – Finds the total number of employees.
AVG() – Calculates the average salary.
MAX() – Finds the highest salary.
MIN() – Finds the lowest salary.
SUM() – Calculates the total salary.
Query
SELECT
    COUNT(*) AS total_employees,
    AVG(salary) AS average_salary,
    MAX(salary) AS highest_salary,
    MIN(salary) AS lowest_salary,
    SUM(salary) AS total_salary
FROM Employee;
📌 OUTPUT

Image Name: 03_aggregate_output.png

4. GROUP BY
Description

GROUP BY is used to group records based on a particular column.

In this experiment, employees are grouped according to their departments to find the number of employees and average salary in each department.

Query
SELECT
    d.dept_name,
    COUNT(e.emp_id) AS employee_count,
    AVG(e.salary) AS average_salary
FROM Department d
JOIN Employee e
ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name;
📌 OUTPUT

Image Name: 04_groupby_output.png

5. HAVING
Description

HAVING is used to filter groups created using GROUP BY.

In this experiment, departments whose average salary is greater than 65,000 are displayed.

Query
SELECT
    d.dept_name,
    AVG(e.salary) AS average_salary
FROM Department d
JOIN Employee e
ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING AVG(e.salary) > 65000;
📌 OUTPUT

Image Name: 05_having_output.png

6. CASE Expression
Description

A CASE expression is used to classify employees according to their salary.

The salary categories are:

High Salary – Salary greater than or equal to 75,000
Medium Salary – Salary greater than or equal to 60,000
Low Salary – Salary below 60,000
Query
SELECT
    emp_name,
    salary,
    CASE
        WHEN salary >= 75000 THEN 'High Salary'
        WHEN salary >= 60000 THEN 'Medium Salary'
        ELSE 'Low Salary'
    END AS salary_category
FROM Employee;
📌 OUTPUT

Image Name: 06_case_output.png

7. ORDER BY
Description

ORDER BY is used to arrange records in a specific order.

In this experiment, employees are displayed in descending order of salary.

Query
SELECT emp_name, salary
FROM Employee
ORDER BY salary DESC;
📌 OUTPUT

Image Name: 07_orderby_output.png

8. JOIN Employee, Department and Project
Description

JOIN is used to combine related information from multiple tables.

In this experiment, the Employee, Department, and Project tables are joined to display employee name, department, project, and salary.

Query
SELECT
    e.emp_name,
    d.dept_name,
    p.project_name,
    e.salary
FROM Employee e
JOIN Department d
ON e.dept_id = d.dept_id
JOIN Project p
ON e.project_id = p.project_id
ORDER BY d.dept_name, e.emp_name;
📌 OUTPUT

Image Name: 08_join_output.png

SQL Concepts Demonstrated

The experiment successfully demonstrates:

Selection
Projection
Aggregate Functions
GROUP BY
HAVING
CASE Expression
ORDER BY
JOIN
Result

The Employee–Department–Project relational database was successfully created with:

30 Employees
5 Departments
8 Projects

All the required SQL operations were successfully demonstrated.

Conclusion

This experiment provides practical understanding of relational database operations. It demonstrates how SQL can be used to retrieve, select, group, filter, classify, sort, and combine data from related tables.