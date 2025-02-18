-- SECTION 1: CREATE TABLE CUSTOMER, MALL, AND SALES

-- 1.1 Create Table customer_data
CREATE TABLE customer_data (
    customer_id VARCHAR(50) PRIMARY KEY,  -- Primary Key
    gender VARCHAR(10),
    age INT,
    payment_method VARCHAR(50)
);

-- 1.2 Create Table shopping_mall_data
CREATE TABLE shopping_mall_data (
    shopping_mall VARCHAR(100) PRIMARY KEY,  -- Primary Key
    construction_year INT,
    area_sqm INT,
    location VARCHAR(100),
    store_count INT
);

-- 1.3 Create Table sales_data
CREATE TABLE sales_data (
    invoice_no VARCHAR(50) PRIMARY KEY,  -- Primary Key
    customer_id VARCHAR(50),             -- Foreign Key to customer_data
    category VARCHAR(50),
    quantity INT,
    invoice_date DATE,
    total_price DECIMAL(10, 2),
    shopping_mall VARCHAR(100),          -- Foreign Key to shopping_mall_data
    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer_data (customer_id),  -- Links to customer_data
    CONSTRAINT fk_shopping_mall
        FOREIGN KEY (shopping_mall)
        REFERENCES shopping_mall_data (shopping_mall)  -- Links to shopping_mall_data
);

-- SECTION 2: CUSTOMER BEHAVIOR ANALYSIS

-- 2.1 Average Purchase Value by Gender and Age Group
SELECT 
    c.gender,
    CASE 
        WHEN age < 25 THEN 'Gen Z'
        WHEN age BETWEEN 25 AND 40 THEN 'Millennials'
        WHEN age BETWEEN 41 AND 56 THEN 'Gen X'
        ELSE 'Baby Boomers'
    END AS age_group,
    ROUND(AVG(s.total_price), 2) as avg_purchase_value,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage_of_total
FROM customer_data c
JOIN sales_data s ON c.customer_id = s.customer_id
GROUP BY 1, 2
ORDER BY 3 DESC;

-- 2.2 Category Preferences by Gender
SELECT 
    c.gender,
    s.category,
    COUNT(*) as purchase_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY c.gender), 2) as percentage_within_gender,
    ROUND(AVG(s.total_price), 2) as avg_purchase_value
FROM customer_data c
JOIN sales_data s ON c.customer_id = s.customer_id
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- 2.3 Seasonal Shopping Patterns by Age Group
SELECT 
    CASE 
        WHEN age < 25 THEN 'Gen Z'
        WHEN age BETWEEN 25 AND 40 THEN 'Millennials'
        WHEN age BETWEEN 41 AND 56 THEN 'Gen X'
        ELSE 'Baby Boomers'
    END AS age_group,
    EXTRACT(MONTH FROM invoice_date) as month,
    COUNT(*) as purchase_count,
    ROUND(AVG(total_price), 2) as avg_purchase_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY CASE 
        WHEN age < 25 THEN 'Gen Z'
        WHEN age BETWEEN 25 AND 40 THEN 'Millennials'
        WHEN age BETWEEN 41 AND 56 THEN 'Gen X'
        ELSE 'Baby Boomers'
    END), 2) as percentage_of_age_group_purchases
FROM customer_data c
JOIN sales_data s ON c.customer_id = s.customer_id
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2.4 Payment Method Analysis by Total Value and Customer Count
WITH payment_metrics AS (
    SELECT 
        c.payment_method,
        COUNT(DISTINCT c.customer_id) as customer_count,
        COUNT(*) as transaction_count,
        ROUND(SUM(s.total_price), 2) as total_revenue,
        ROUND(AVG(s.total_price), 2) as avg_transaction_value
    FROM customer_data c
    JOIN sales_data s ON c.customer_id = s.customer_id
    GROUP BY c.payment_method
)
SELECT 
    payment_method,
    customer_count,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    ROUND(customer_count * 100.0 / SUM(customer_count) OVER (), 2) as percentage_of_customers,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) as percentage_of_revenue
FROM payment_metrics
ORDER BY total_revenue DESC;

-- SECTION 3: SALES PERFORMANCE ANALYSIS

-- 3.1 Quarterly Sales Trend with Moving Average
WITH quarterly_sales AS (
    SELECT 
        DATE_TRUNC('quarter', invoice_date) as quarter,
        COUNT(*) as quarterly_transactions,
        ROUND(SUM(total_price), 2) as quarterly_revenue
    FROM sales_data
    GROUP BY 1
),
moving_averages AS (
    SELECT 
        quarter,
        quarterly_transactions,
        quarterly_revenue,
        ROUND(AVG(quarterly_revenue) OVER (
            ORDER BY quarter 
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ), 2) as moving_avg_revenue
    FROM quarterly_sales
)
SELECT 
    quarter,
    quarterly_transactions,
    quarterly_revenue,
    moving_avg_revenue,
    ROUND((quarterly_revenue - LAG(quarterly_revenue) OVER (ORDER BY quarter)) * 100.0 / 
        NULLIF(LAG(quarterly_revenue) OVER (ORDER BY quarter), 0), 2) as revenue_growth_percentage
FROM moving_averages
ORDER BY quarter;

-- 3.2 Monthly Revenue Growth
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', invoice_date) as month,
        SUM(total_price) as revenue
    FROM sales_data
    GROUP BY 1
)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) as prev_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0 / 
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) as revenue_growth_percentage
FROM monthly_revenue
ORDER BY 1;

-- 3.3 Category Performance Analysis
SELECT 
    category,
    COUNT(*) as total_sales,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as sales_percentage,
    ROUND(SUM(total_price), 2) as total_revenue,
    ROUND(SUM(total_price) * 100.0 / SUM(SUM(total_price)) OVER (), 2) as revenue_percentage,
    ROUND(AVG(total_price), 2) as avg_transaction_value
FROM sales_data
GROUP BY 1
ORDER BY 4 DESC;

-- 3.4 Category Performance by Day of Week
SELECT 
    TO_CHAR(invoice_date, 'Day') as day_of_week,
    category,
    COUNT(*) as sales_count,
    ROUND(SUM(total_price), 2) as total_revenue,
    ROUND(AVG(total_price), 2) as avg_transaction_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY category), 2) as percentage_of_category_sales
FROM sales_data
GROUP BY 1, 2
ORDER BY 2, 4 DESC;

-- SECTION 4: MALL PERFORMANCE ANALYSIS

-- 4.1 Mall Performance Overview (Revenue, Traffic, Efficiency)
WITH mall_sales AS (
    SELECT 
        m.shopping_mall,
        m.area_sqm,
        m.store_count,
        COUNT(s.invoice_no) as total_transactions,
        SUM(s.total_price) as total_revenue
    FROM shopping_mall_data m
    LEFT JOIN sales_data s ON m.shopping_mall = s.shopping_mall
    GROUP BY m.shopping_mall, m.area_sqm, m.store_count
),
efficiency_metrics AS (
    SELECT 
        shopping_mall,
        total_transactions,
        total_revenue,
        ROUND(total_revenue / NULLIF(area_sqm, 0), 2) as revenue_per_sqm,
        ROUND(total_revenue / NULLIF(store_count, 0), 2) as revenue_per_store,
        ROUND(total_transactions::numeric / NULLIF(store_count, 0), 2) as transactions_per_store
    FROM mall_sales
)
SELECT 
    e.*,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) as revenue_percentage,
    ROUND(total_transactions * 100.0 / SUM(total_transactions) OVER (), 2) as transaction_percentage,
    RANK() OVER (ORDER BY revenue_per_sqm DESC) as efficiency_rank
FROM efficiency_metrics e
ORDER BY revenue_per_sqm DESC;

-- 4.2 Mall Age Impact Analysis
SELECT 
    m.shopping_mall,
    m.construction_year,
    EXTRACT(YEAR FROM NOW()) - m.construction_year as mall_age,
    ROUND(AVG(s.total_price), 2) as avg_transaction_value,
    COUNT(s.invoice_no) as total_transactions,
    ROUND(SUM(s.total_price), 2) as total_revenue
FROM shopping_mall_data m
LEFT JOIN sales_data s ON m.shopping_mall = s.shopping_mall
GROUP BY m.shopping_mall, m.construction_year
ORDER BY mall_age;

-- 4.3 Space Efficiency Analysis
SELECT 
    m.shopping_mall,
    m.area_sqm,
    ROUND(SUM(s.total_price) / m.area_sqm, 2) as revenue_per_sqm,
    ROUND(COUNT(s.invoice_no) * 1.0 / m.area_sqm * 1000, 2) as transactions_per_1000_sqm,
    ROUND(m.store_count * 1.0 / m.area_sqm * 1000, 2) as stores_per_1000_sqm
FROM shopping_mall_data m
LEFT JOIN sales_data s ON m.shopping_mall = s.shopping_mall
GROUP BY m.shopping_mall, m.area_sqm, m.store_count
ORDER BY revenue_per_sqm DESC;

-- 4.4 Location Performance Analysis
SELECT 
    m.location,
    COUNT(DISTINCT m.shopping_mall) as mall_count,
    ROUND(AVG(m.area_sqm), 2) as avg_mall_size,
    ROUND(SUM(s.total_price), 2) as total_revenue,
    COUNT(s.invoice_no) as total_transactions,
    ROUND(AVG(s.total_price), 2) as avg_transaction_value
FROM shopping_mall_data m
LEFT JOIN sales_data s ON m.shopping_mall = s.shopping_mall
GROUP BY m.location
ORDER BY total_revenue DESC;

-- 4.5 Mall Category Specialization
WITH category_mall_revenue AS (
    SELECT 
        s.shopping_mall,
        s.category,
        SUM(s.total_price) as category_revenue,
        COUNT(*) as category_transactions
    FROM sales_data s
    GROUP BY s.shopping_mall, s.category
)
SELECT 
    shopping_mall,
    category,
    ROUND(category_revenue, 2) as category_revenue,
    category_transactions,
    ROUND(category_revenue * 100.0 / SUM(category_revenue) OVER (PARTITION BY shopping_mall), 2) as percentage_of_mall_revenue
FROM category_mall_revenue
WHERE category_revenue > 0
ORDER BY shopping_mall, category_revenue DESC;

-- 4.6 Mall Customer Demographics Analysis
WITH customer_demographics AS (
    SELECT 
        s.shopping_mall,
        CASE 
            WHEN c.age < 25 THEN 'Gen Z'
            WHEN c.age BETWEEN 25 AND 40 THEN 'Millennials'
            WHEN c.age BETWEEN 41 AND 56 THEN 'Gen X'
            ELSE 'Baby Boomers'
        END AS age_group,
        c.gender,
        s.total_price
    FROM sales_data s
    JOIN customer_data c ON s.customer_id = c.customer_id
),
mall_demographics AS (
    SELECT 
        shopping_mall,
        age_group,
        gender,
        COUNT(*) as customer_count,
        ROUND(AVG(total_price), 2) as avg_transaction_value,
        ROUND(SUM(total_price), 2) as total_revenue
    FROM customer_demographics
    GROUP BY shopping_mall, age_group, gender
)
SELECT 
    shopping_mall,
    age_group,
    gender,
    customer_count,
    avg_transaction_value,
    total_revenue,
    ROUND(customer_count * 100.0 / SUM(customer_count) OVER (PARTITION BY shopping_mall), 2) as percentage_of_mall_customers,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (PARTITION BY shopping_mall), 2) as percentage_of_mall_revenue
FROM mall_demographics
ORDER BY shopping_mall, customer_count DESC;


