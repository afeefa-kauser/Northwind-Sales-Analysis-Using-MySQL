-- ============================================
-- NORTHWIND SALES ANALYSIS USING MYSQL
-- ============================================
-- Project: Sales and Customer Analysis
-- Database: Northwind
-- Tools: MySQL
-- ============================================

USE northwind;
show tables;

DESCRIBE customers;
DESCRIBE orders;
DESCRIBE order_details;
DESCRIBE products;
DESCRIBE employees;
DESCRIBE suppliers;
DESCRIBE purchase_orders;
DESCRIBE purchase_order_details;
DESCRIBE inventory_transactions;
DESCRIBE shippers;

#------------------------------------------SALES PERFORMANCE--------------------------------------------------
#How many customers are there?
SELECT count(distinct id)  as Total_Customers
from  customers;

#How many orders were placed?
SELECT COUNT(*) AS total_orders
FROM orders;

#How many products are available?
SELECT COUNT(*) AS total_products
FROM products;

#Calculate Total Sales
SELECT 
	SUM(quantity*unit_price *(1-discount) ) as total_sales
FROM order_details;

#Top 10 Customers by Total Sales
SELECT c.id as customer_Id,
	c.first_name,
    c.last_name,
    sum(od.quantity*od.unit_price *(1-od.discount)) as Total_sales
FROM customers 	c
join orders o
on c.id=o.customer_id
join order_details od
on od.order_id=o.id
group by 
c.id,
c.first_name,
c.last_name
order by Total_sales desc
limit 10;

#Top 10 Best-Selling Products by Revenue
SELECT 
	p.id as Product_id,
	p.product_name,
    p.category,
    sum(od.quantity) as total_quantity_sold,
    round(
    sum(od.quantity*od.unit_price*(1-od.discount)),2) as total_revenue
from products p
join order_details od
on p.id=od.product_id
group by p.id,p.product_name,p.category
order by total_revenue desc
limit 10;

#Sales Performance by Category
SELECT 
	p.category,
    round(
    sum(od.quantity*od.unit_price*(1-od.discount)),2) as total_Sales
FROM products p
join order_details od
on od.product_id=p.id
group by 
p.category
order by 
total_Sales desc;

#-----------------------------------Time-Series Analysis: Monthly Sales Trend---------------------------------------------------


#Monthly Sales Trend Query

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month_number,
    DATE_FORMAT(o.order_date, '%M %Y') AS month_name,
    ROUND(
        SUM(
            od.quantity * od.unit_price * (1 - od.discount)),2) AS total_sales,
    COUNT(DISTINCT o.id) AS total_orders
FROM orders AS o
JOIN order_details AS od
    ON o.id = od.order_id
GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m'),
    DATE_FORMAT(o.order_date, '%M %Y')
ORDER BY month_number;
    
#Month-over-Month (MoM) Sales Growth
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,
        SUM(
            od.quantity * od.unit_price * (1 - od.discount)
        ) AS total_sales
    FROM orders AS o
    JOIN order_details AS od
        ON o.id = od.order_id
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),
sales_with_previous_month AS (
    SELECT
        sales_month,
        total_sales,
        LAG(total_sales) OVER (
            ORDER BY sales_month
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    sales_month,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(previous_month_sales, 2) AS previous_month_sales,

    ROUND(
        (
            (total_sales - previous_month_sales)
            / previous_month_sales
        ) * 100,
        2
    ) AS mom_growth_percentage
FROM sales_with_previous_month
ORDER BY sales_month;

#Customer Ranking by Total Sales
WITH customer_sales AS (
    SELECT
        c.id AS customer_id,
        c.company,
        c.first_name,
        c.last_name,

        SUM(
            od.quantity * od.unit_price * (1 - od.discount)
        ) AS total_sales

    FROM customers AS c

    JOIN orders AS o
        ON c.id = o.customer_id

    JOIN order_details AS od
        ON o.id = od.order_id

    GROUP BY
        c.id,
        c.company,
        c.first_name,
        c.last_name
)

SELECT
    customer_id,
    company,
    first_name,
    last_name,
    ROUND(total_sales, 2) AS total_sales,

    RANK() OVER (
        ORDER BY total_sales DESC
    ) AS customer_rank
FROM customer_sales
ORDER BY customer_rank;

#Top 3 Products Within Each Category
WITH product_sales AS (
    SELECT
        p.id AS product_id,
        p.product_name,
        p.category,

        SUM(od.quantity) AS total_quantity_sold,

        SUM(
            od.quantity * od.unit_price * (1 - od.discount)
        ) AS total_sales

    FROM products AS p

    JOIN order_details AS od
        ON p.id = od.product_id

    GROUP BY
        p.id,
        p.product_name,
        p.category
),

ranked_products AS (
    SELECT
        product_id,
        product_name,
        category,
        total_quantity_sold,
        total_sales,

        RANK() OVER (
            PARTITION BY category
            ORDER BY total_sales DESC
        ) AS product_rank

    FROM product_sales
)

SELECT
    product_id,
    product_name,
    category,
    total_quantity_sold,
    ROUND(total_sales, 2) AS total_sales,
    product_rank

FROM ranked_products
WHERE product_rank <= 3
ORDER BY
    category,
    product_rank;

#Running Total of Monthly Sales
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,

        SUM(
            od.quantity * od.unit_price * (1 - od.discount)
        ) AS total_sales

    FROM orders AS o

    JOIN order_details AS od
        ON o.id = od.order_id

    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)

SELECT
    sales_month,

    ROUND(total_sales, 2) AS monthly_sales,

    ROUND(
        SUM(total_sales) OVER (
            ORDER BY sales_month
        ),
        2
    ) AS running_total_sales
FROM monthly_sales
ORDER BY sales_month;

#Customer Purchase Frequency Analysis
SELECT
    c.id AS customer_id,
    c.company,
    c.first_name,
    c.last_name,

    COUNT(DISTINCT o.id) AS total_orders,

    CASE
        WHEN COUNT(DISTINCT o.id) >= 10 THEN 'High Frequency'
        WHEN COUNT(DISTINCT o.id) BETWEEN 5 AND 9 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END AS customer_segment

FROM customers AS c
LEFT JOIN orders AS o
    ON c.id = o.customer_id

GROUP BY
    c.id,
    c.company,
    c.first_name,
    c.last_name
ORDER BY total_orders DESC;

#Employee Sales Performance
WITH employee_sales AS (
    SELECT
        e.id AS employee_id,
        e.first_name,
        e.last_name,

        COUNT(DISTINCT o.id) AS total_orders,

        SUM(
            od.quantity * od.unit_price * (1 - od.discount)
        ) AS total_sales

    FROM employees AS e

    JOIN orders AS o
        ON e.id = o.employee_id

    JOIN order_details AS od
        ON o.id = od.order_id

    GROUP BY
        e.id,
        e.first_name,
        e.last_name
)

SELECT
    employee_id,
    first_name,
    last_name,
    total_orders,
    ROUND(total_sales, 2) AS total_sales,

    RANK() OVER (
        ORDER BY total_sales DESC
    ) AS sales_rank
FROM employee_sales
ORDER BY sales_rank;