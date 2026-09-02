//Phase 1: Snowflake Setup
//Task 1: Create Warehouse
CREATE WAREHOUSE IF NOT EXISTS SALES_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

SHOW WAREHOUSES LIKE 'SALES_WH';

//Task 2: Create database
CREATE DATABASE IF NOT EXISTS CUSTOMER_SALES_DB;
SHOW DATABASES LIKE 'CUSTOMER_SALES_DB';

//Task 3: Create Schema
CREATE SCHEMA IF NOT EXISTS CUSTOMER_SALES_DB.SALES_SCHEMA;
SHOW SCHEMAS LIKE 'SALES_SCHEMA' IN DATABASE CUSTOMER_SALES_DB;

//Task 4: Select the Database and Schema for the current session.
USE WAREHOUSE SALES_WH;
USE DATABASE CUSTOMER_SALES_DB;
USE SCHEMA SALES_SCHEMA;

SELECT
  CURRENT_WAREHOUSE(),
  CURRENT_DATABASE(),
  CURRENT_SCHEMA();

  //Task 5: Create a CSV File Format to load the CSV files.
CREATE FILE FORMAT IF NOT EXISTS CSV_FILE_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

DESC FILE FORMAT CSV_FILE_FORMAT;

//Task 6: Create an Internal Stage named SALES_STAGE to store the CSV files.
CREATE STAGE IF NOT EXISTS SALES_STAGE
  FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT');

SHOW STAGES LIKE 'SALES_STAGE';

//Phase 2
//Task 7: upload and verify csv files
USE WAREHOUSE SALES_WH;
USE DATABASE CUSTOMER_SALES_DB;
USE SCHEMA SALES_SCHEMA;

REMOVE @SALES_STAGE/orders.csv.xlsx;

LIST @SALES_STAGE;

LIST @SALES_STAGE;

//Task 8: Create Snowflake tables
CREATE TABLE IF NOT EXISTS CUSTOMERS (
  customer_id NUMBER(10,0),
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  email VARCHAR(100),
  phone VARCHAR(20),
  address VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS FOODITEMS (
  food_id NUMBER(10,0),
  name VARCHAR(100),
  price NUMBER(10,2),
  category VARCHAR(50),
  availability VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS ORDERS (
  order_id NUMBER(10,0),
  customer_id NUMBER(10,0),
  food_id NUMBER(10,0),
  quantity NUMBER(10,0),
  order_date TIMESTAMP_NTZ,
  status VARCHAR(20),
  total_amount NUMBER(12,2)
);

SHOW TABLES;

//Task 9: Load all CSV files into their respective tables using the COPY INTO command.
COPY INTO CUSTOMERS
FROM @SALES_STAGE/customers.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT');

COPY INTO FOODITEMS
FROM @SALES_STAGE/fooditems.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT');

COPY INTO ORDERS
FROM @SALES_STAGE/orders.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT');
//Task 10: Verify that the data has been loaded successfully by displaying all records from each table

SELECT COUNT(*) AS fooditems_loaded
FROM FOODITEMS;

REMOVE @SALES_STAGE/fooditems.csv;
LIST @SALES_STAGE;

TRUNCATE TABLE FOODITEMS;

COPY INTO FOODITEMS
FROM @SALES_STAGE/fooditems.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT')
FORCE = TRUE;

SELECT COUNT(*) AS fooditems_loaded
FROM FOODITEMS;

LIST @SALES_STAGE;

SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL

SELECT 'FOODITEMS', COUNT(*) FROM FOODITEMS
UNION ALL

SELECT 'ORDERS', COUNT(*) FROM ORDERS;

TRUNCATE TABLE CUSTOMERS;

COPY INTO CUSTOMERS
FROM @SALES_STAGE/customers.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT')
FORCE = TRUE;
SELECT COUNT(*) AS customers_loaded
FROM CUSTOMERS;

SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL
SELECT 'FOODITEMS', COUNT(*) FROM FOODITEMS
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM ORDERS;

//Task 11: Display All Customer Details
SELECT * FROM CUSTOMERS
ORDER BY customer_id;
//Task 12: Display All Food Item Details
SELECT * FROM FOODITEMS
ORDER BY food_id;
//Task 13: Display All Order Details
SELECT * FROM ORDERS
ORDER BY order_id;

//Task 14: Generate a Customer-wise Sales Report
SELECT
  c.customer_id,
  c.first_name || ' ' || c.last_name AS customer_name,
  SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
  ON c.customer_id = o.customer_id
GROUP BY
  c.customer_id,
  c.first_name,
  c.last_name
ORDER BY c.customer_id;

//Task 15: Find the Highest Spending Customer
SELECT
  c.customer_id,
  c.first_name || ' ' || c.last_name AS customer_name,
  SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
  ON c.customer_id = o.customer_id
GROUP BY
  c.customer_id,
  c.first_name,
  c.last_name
ORDER BY total_amount_spent DESC
LIMIT 1;

//Task 16: Calculate the Total Business Revenue
DESC TABLE ORDERS;
SELECT SUM(TOTAL_AMOUNT) AS "Total Revenue"
FROM Orders;

//Task 17: Generate a Category-wise Revenue Report
SELECT
    f.CATEGORY AS "Food Category",
    SUM(o.TOTAL_AMOUNT) AS "Total Revenue"
FROM Orders o
INNER JOIN FoodItems f
    ON o.FOOD_ID = f.FOOD_ID
GROUP BY f.CATEGORY
ORDER BY "Total Revenue" DESC;

//Task 18: Generate an Order Status-wise Revenue Report
SELECT
    STATUS AS "Order Status",
    SUM(TOTAL_AMOUNT) AS "Total Revenue"
FROM Orders
GROUP BY STATUS
ORDER BY "Total Revenue" DESC;

//Task 19: Display the Top three Customers Based on Total Spending
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(o.TOTAL_AMOUNT) DESC) AS "Rank",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME) AS "Customer Name",
    SUM(o.TOTAL_AMOUNT) AS "Total Spent"
FROM Customers c
INNER JOIN Orders o
    ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME
ORDER BY "Rank"
LIMIT 3;

//Task 20: Generate a Customer Purchase Frequenccy Report
SELECT
    c.CUSTOMER_ID AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME) AS "Customer Name",
    COUNT(o.ORDER_ID) AS "Orders Placed"
FROM Customers c
INNER JOIN Orders o
    ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME
ORDER BY c.CUSTOMER_ID;

//Task 21: Display All Delivered Orders 
SELECT
    ORDER_ID AS "Order ID",
    CUSTOMER_ID AS "Customer ID",
    FOOD_ID AS "Food ID",
    STATUS,
    TOTAL_AMOUNT AS "Total Amount"
FROM Orders
WHERE STATUS = 'Delivered'
ORDER BY ORDER_ID;

//Task 22: Display All Orders Placed After 12 July 2026
SELECT
    o.ORDER_ID AS "Order ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME) AS "Customer Name",
    o.ORDER_DATE AS "Order Date",
    o.STATUS AS "Status",
    o.TOTAL_AMOUNT AS "Total Amount"
FROM Orders o
INNER JOIN Customers c
    ON o.CUSTOMER_ID = c.CUSTOMER_ID
WHERE o.ORDER_DATE > '2026-07-12'
ORDER BY o.ORDER_DATE;
//Phase 4: Views
//Task 23: Create the CUSTOMER_SALES_REPORT View
CREATE OR REPLACE VIEW CUSTOMER_SALES_REPORT AS
SELECT
    c.CUSTOMER_ID AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME) AS "Customer Name",
    SUM(o.TOTAL_AMOUNT) AS "Total Amount Spent"
FROM Customers c
INNER JOIN Orders o
    ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME;

//Task 24: Retrieve All Records from the CUSTOMER_SALES_REPORT View
SELECT *
FROM CUSTOMER_SALES_REPORT;

//Task 25: Sort the View Data by Total Amount Spent in Descending Order
SELECT *
FROM CUSTOMER_SALES_REPORT
ORDER BY "Total Amount Spent" DESC;

