-- Tabel Customer
CREATE TABLE customer (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100),
    segment VARCHAR(50)
);

-- Tabel Region
CREATE TABLE region (
    postal_code VARCHAR(20) PRIMARY KEY,
    country VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    region VARCHAR(50)
);

-- Tabel Product
CREATE TABLE product (
    product_id VARCHAR(30) PRIMARY KEY,
    category VARCHAR(50),
    subcategory VARCHAR(50),
    product_name VARCHAR(255)
);

-- Tabel Shipment
CREATE TABLE shipment (
    order_id VARCHAR(30) PRIMARY KEY,
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50)
);

-- Tabel Orders
CREATE TABLE orders (
    order_line_id SERIAL PRIMARY KEY,
    order_id VARCHAR(30),
    customer_id VARCHAR(20),
    postal_code VARCHAR(10),
    product_id VARCHAR(30),
    sales NUMERIC(10,2),
    quantity INTEGER,
    discount NUMERIC(4,2),
    profit NUMERIC(10,4),

    FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (postal_code) REFERENCES region(postal_code),
    FOREIGN KEY (order_id) REFERENCES shipment(order_id)
);

TRUNCATE TABLE orders, shipment, region, product, customer CASCADE;

-- Import Customer
copy customer
FROM 'E:/Project Portofolio Data Analis/Project 3/Dataset SQL Join/customer.csv'
DELIMITER ','
CSV HEADER;

-- Import Region
COPY region(country, city, state, postal_code, region)
FROM 'E:/Project Portofolio Data Analis/Project 3/Dataset SQL Join/region.csv'
DELIMITER ','
CSV HEADER;

-- Import Product
copy product(product_id, category, subcategory, product_name)
FROM 'E:/Project Portofolio Data Analis/Project 3/Dataset SQL Join/product.csv'
DELIMITER ','
CSV HEADER;

-- Import Shipment
copy shipment
FROM 'E:/Project Portofolio Data Analis/Project 3/Dataset SQL Join/shipment.csv'
DELIMITER ','
CSV HEADER;

-- Import Orders
copy orders(order_id, customer_id, postal_code, product_id, sales, quantity, discount, profit)
FROM 'E:/Project Portofolio Data Analis/Project 3/Dataset SQL Join/orders.csv'
DELIMITER ','
CSV HEADER;

-- Cek Jumlah Baris
SELECT COUNT(*) FROM customer;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM product;
SELECT COUNT(*) FROM region;
SELECT COUNT(*) FROM shipment;

-- Cek Duplicate Table Customer
SELECT customer_id, COUNT(*)
FROM customer
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Cek Duplicate Table Region
SELECT postal_code, COUNT(*)
FROM region
GROUP BY postal_code
HAVING COUNT(*) > 1;

-- Cek Duplicate Table Shipment
SELECT order_id, COUNT(*)
FROM shipment
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Cek Duplicate Table Product
SELECT product_id, COUNT(*)
FROM product
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Cek Duplicate Table Orders
-- Terdapat beberapa duplicate yang ditemukan dan sebagian besar merupakan valid multi-line transaction karena memiliki perbedaan quantity dan sales.
SELECT 
    order_id,
    product_id,
    customer_id,
    COUNT(*) as total_duplicate
FROM orders
GROUP BY order_id, product_id, customer_id
HAVING COUNT(*) > 1;

-- Menghapus true duplicate row
DELETE FROM orders a
USING orders b
WHERE a.order_line_id > b.order_line_id
AND a.order_id = b.order_id
AND a.product_id = b.product_id
AND a.customer_id = b.customer_id
AND a.quantity = b.quantity
AND a.sales = b.sales
AND a.discount = b.discount
AND a.profit = b.profit
AND a.postal_code = b.postal_code;

-- validation duplicate row
SELECT COUNT(*)
FROM (
    SELECT order_id, product_id, customer_id,
           quantity, sales, discount, profit, postal_code,
           COUNT(*)
    FROM orders
    GROUP BY order_id, product_id, customer_id,
             quantity, sales, discount, profit, postal_code
    HAVING COUNT(*) > 1
) t_duplicate;

-- cek missing value
SELECT *
FROM orders
WHERE customer_id IS NULL
   OR product_id IS NULL
   OR postal_code IS NULL
   OR sales IS NULL
   OR profit IS NULL;

-- Profitability by Region & Category
SELECT 
    r.region,
    p.category,
    SUM(o.sales) AS total_sales,
    SUM(o.profit) AS total_profit
FROM orders o
JOIN region r 
    ON o.postal_code = r.postal_code
JOIN product p 
    ON o.product_id = p.product_id
GROUP BY r.region, p.category
ORDER BY total_profit ASC;

-- Top Customer Lifetime Value(CLV)
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment,
    SUM(o.sales) AS total_sales,
    SUM(o.profit) AS total_profit,
    ROUND(SUM(o.profit) / SUM(o.sales) * 100, 2) AS profit_margin_pct
FROM orders o
JOIN customer c 
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment
ORDER BY total_profit DESC
LIMIT 10;

-- Shipping Performance
SELECT 
    ship_mode,
    COUNT(*) AS total_orders,
    ROUND(AVG(ship_date - order_date), 2) AS avg_shipping_days,
    MIN(ship_date - order_date) AS min_days,
    MAX(ship_date - order_date) AS max_days
FROM shipment
GROUP BY ship_mode
ORDER BY avg_shipping_days;

-- Perbandingan Average Shipping Days antara First Class & Standard Class
SELECT 
    ship_mode,
    ROUND(AVG(ship_date - order_date), 2) AS avg_days
FROM shipment
WHERE ship_mode IN ('First Class', 'Standard Class')
GROUP BY ship_mode;

-- Mencari 3 produk paling laku (berdasarkan quantity) di tiap kategori
SELECT category, product_name, total_qty_sold
FROM (
    SELECT 
        category, 
        product_name, 
        SUM(quantity) as total_qty_sold,
        RANK() OVER(PARTITION BY category ORDER BY SUM(quantity) DESC) as rank_per_cat
    FROM v_order_master
    GROUP BY category, product_name
) ranked_products
WHERE rank_per_cat <= 3;

-- Menghitung pertumbuhan profit dibandingkan bulan sebelumnya
WITH Monthly_Profit AS (
    SELECT 
        DATE_TRUNC('month', order_date) as order_month,
        SUM(profit) as total_profit
    FROM v_order_master
    GROUP BY 1
),
Profit_Comparison AS (
    SELECT 
        order_month,
        total_profit,
        LAG(total_profit) OVER(ORDER BY order_month) as last_month_profit
    FROM Monthly_Profit
)
SELECT 
    order_month,
    total_profit,
    last_month_profit,
    ROUND(((total_profit - last_month_profit) / NULLIF(last_month_profit, 0)) * 100, 2) as growth_percentage
FROM Profit_Comparison
ORDER BY order_month;

-- Menggabungkan Semua Tabel
CREATE OR REPLACE VIEW v_order_master AS
SELECT 
    o.order_line_id,
    o.order_id,
    s.order_date,
    s.ship_date,
    s.ship_mode,
    c.customer_name,
    c.segment,
    r.city,
    r.state,
    r.region,
    p.category,
    p.subcategory,
    p.product_name,
    o.sales,
    o.quantity,
    o.discount,
    o.profit
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
JOIN product p ON o.product_id = p.product_id
JOIN region r ON o.postal_code = r.postal_code
JOIN shipment s ON o.order_id = s.order_id;

SELECT * FROM v_order_master;