/* =========================================================
   E-COMMERCE DATA CLEANING
   =========================================================

   Objective:
   Clean and validate the raw e-commerce dataset so that
   the final data can be used for SQL business analysis
   and Power BI dashboard development.

   Data Cleaning Steps:
   1. Inspect the table structure and imported data
   2. Check the total number of records
   3. Identify missing (NULL) values
   4. Identify and remove duplicate records
   5. Identify and handle invalid quantities
   6. Identify and handle invalid prices
   7. Remove unwanted zero-price transactions
   8. Standardize text values
   9. Verify date and numeric data types
   10. Perform final data-quality validation

   Final cleaned table:
   ecommerce_cleaneddata

   Final records:
   534,125
   ========================================================= */

-- Create the raw e-commerce table to store the imported dataset.
-- Appropriate data types are assigned to each column based on the data.
create table ecommerce_data (
    InvoiceNo varchar(20),
    StockCode varchar(20),
    ProductDescription varchar(255),
    Quantity int,
    InvoiceDate datetime,
    UnitPrice decimal(10,2),
    CustomerID int NULL,
    Country varchar(100)
);

-- Import the CSV file into the raw e-commerce table.
-- latin1 is used because the dataset contains special characters.
-- STR_TO_DATE converts the text date into DATETIME.
-- NULLIF converts blank CustomerID values into SQL NULL.

load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/data.csv'
into table ecommerce_data
character set latin1
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
    InvoiceNo,
    StockCode,
    ProductDescription,
    Quantity,
    @InvoiceDate,
    UnitPrice,
    @CustomerID,
    Country
)
set
InvoiceDate = str_to_date(@InvoiceDate, '%m/%d/%Y %H:%i'),
CustomerID = nullif(@CustomerID, '');


-- Check the structure and data types of the imported table.
describe ecommerce_data;

-- View the imported records to inspect the raw dataset.
select * from ecommerce_data;

-- Count the total number of rows imported into the raw table.
-- This confirms whether the dataset was imported completely.
select count(*) from ecommerce_data;

--  It shows 10 rows of data for a quick inspection.
select * from ecommerce_data limit 10;

-- Count the records where CustomerID is missing.
-- NULL values are checked using IS NULL.
select count(*) from ecommerce_data where CustomerID is null;
select count(*) as total_rows , sum(customerid is null) as missing_ids from ecommerce_data;


-- Check the null values of every important column. 
select 
       sum(case when InvoiceNo is null then 1 else 0 end) as invoice_nulls,
       sum(case when StockCode is null then 1 else 0 end) as stockcode_nulls,
       sum(case when ProductDescription is null then 1 else 0 end) as productdescription_nulls,
       sum(case when Quantity is null then 1 else 0 end) as quantity_nulls,
       sum(case when InvoiceDate is null then 1 else 0 end) as invoicedate_nulls,
       sum(case when UnitPrice is null then 1 else 0 end) as unitprice_nulls,
       sum(case when CustomerID is null then 1 else 0 end) as customerid_nulls,
       sum(case when Country is null then 1 else 0 end) as country_nulls
from ecommerce_data;


-- Identify exact duplicate transaction records.
-- GROUP BY compares all transaction columns together.
-- HAVING COUNT(*) > 1 returns records appearing more than once.
select * , count(*) as duplicate_count 
from ecommerce_data
group by InvoiceNo,
		 StockCode,
		 ProductDescription,
		 Quantity,
		 InvoiceDate,
		 UnitPrice,
		 CustomerID,
		 Country
having count(*) > 1 ; 


-- Create a new table for data cleaning.
-- Check the structure of the table.    
create table ecommerce_cleaneddata as 
select * from  ecommerce_data ;
show tables;
select * from ecommerce_cleaneddata;
select count(*) from ecommerce_cleaneddata;
describe ecommerce_cleaneddata;
 
 
-- Assign a row number to each duplicate group.
-- PARTITION BY groups identical transactions.
-- ROW_NUMBER identifies the first and repeated records. 
select * , row_number() over ( partition by InvoiceNo ,
                                            StockCode ,
                                            ProductDescription,
                                            Quantity,
                                            InvoiceDate,
                                            UnitPrice,
                                            CustomerID,
                                            Country
                                order by InvoiceNo             
                              ) as row_no
                    from ecommerce_cleaneddata;     
                   

-- Use a Common Table Expression (CTE) to identify duplicate rows.
-- Rows with row_no greater than 1 are duplicate records.
with duplicate_row as (
select * , row_number() over ( partition by InvoiceNo,
												  StockCode ,
                                                  ProductDescription,
                                                  Quantity,
                                                  InvoiceDate,
                                                  UnitPrice,
                                                  CustomerID,
                                                  Country
                                         order by InvoiceNo
                                      ) as row_no
            from ecommerce_cleaneddata 
            )
 select * from duplicate_row            
where row_no > 1;

-- Create the final working table while keeping only the first
-- record from each duplicate group.
-- ROW_NUMBER = 1 keeps one copy of each unique transaction.
create table ecommerce_final as 
with duplicate_rows  as 
 (                 
      select * , row_number() over ( partition by InvoiceNo,
                                                  StockCode,
                                                  ProductDescription,
                                                  Quantity,
                                                  InvoiceDate,
                                                  UnitPrice,
                                                  CustomerID,
                                                  Country
                                     order by InvoiceNo
                                    ) as row_no
                    from ecommerce_cleaneddata
   )
   select  InvoiceNo,
           StockCode,
		   ProductDescription,
           Quantity,
           InvoiceDate,
           UnitPrice,
           CustomerID,
           Country
    from duplicate_rows 
    where row_no = 1;


-- Count rows in the dataset before duplicate removal.    
select count(*) as original_rows 
from ecommerce_cleaneddata;

-- Count rows in the dataset after duplicate removal.    
select count(*) as cleaned_rows 
from ecommerce_final;

-- Calculate how many duplicate rows were removed
-- by comparing the original and cleaned row counts.    
select ( select count(*) from ecommerce_cleaneddata) - 
	   ( select count(*) from ecommerce_final)
	as duplicate_rows_removed;


-- Identify transactions with zero or negative quantities.
-- These records require investigation because they may represent
-- cancellations, returns, adjustments, or invalid transactions.    
select count(*) as invalid_quantity 
   from ecommerce_final
   where Quantity <= 0;


-- Count cancellation/return invoices identified by InvoiceNo starting with C.

select  count(*) as cancelled_orders
    from ecommerce_final
    where InvoiceNo like 'c%';

-- Investigate zero or negative quantities that are not marked
-- as cancellation invoices.
-- These records may be invalid or non-sales adjustments.
    
select * from ecommerce_final 
where Quantity <= 0 and InvoiceNo not like 'c%';

select count(*) as suspicious_rows 
      from ecommerce_final
  where  Quantity <=0
  and InvoiceNo not like 'c%'
  and UnitPrice = 0
  and (ProductDescription is null or trim(ProductDescription) = '')
  and CustomerID is null;
  
select *
from ecommerce_final
where Quantity <= 0
  and InvoiceNo not like 'C%'
 and not (
      UnitPrice = 0
      and (ProductDescription is null or trim(ProductDescription) = '')
      and CustomerID is null  )
LIMIT 20;  
  
  
  
select  count(*)
from ecommerce_final
where Quantity <= 0
  and InvoiceNo not like 'C%'
 and not (
      UnitPrice = 0
      and (ProductDescription is null or trim(ProductDescription) = '')
      and CustomerID is null  )  ;
      
select
    InvoiceNo,
    StockCode,
    ProductDescription,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
from ecommerce_final
where Quantity <= 0
  and InvoiceNo not like 'C%'
  and not (
      UnitPrice = 0
      and (ProductDescription is null or TRIM(ProductDescription) = '')
      and CustomerID is null
  )
order by Quantity
limit 50;      



-- Profile suspicious quantity records by checking zero prices,
-- missing CustomerID values, and missing product descriptions.
-- This helps determine whether the records should be removed.

select
    count(*) as total_suspicious_rows,
    sum(case when UnitPrice = 0 then 1 else 0 end) as zero_price_rows,
    sum(case when CustomerID is null then 1 else 0 end) as missing_customer_rows,
    sum(case
        when ProductDescription is null
          or trim(ProductDescription) = ''
        then 1 else 0
    end) as missing_description_rows
from ecommerce_final
where Quantity <= 0
  and InvoiceNo not like 'C%'
  and not (
      UnitPrice = 0
      and (ProductDescription is null or trim(ProductDescription) = '')
      and CustomerID is null
  );
 
 
 -- Create a backup of the final working table before performing
-- destructive DELETE operations.
-- This allows the data to be restored if a mistake occurs.

  create table ecommerce_final_backup as 
  select * from ecommerce_final ;
  
select count(*) from ecommerce_final_backup;
    
-- Remove suspicious non-sales records after investigation.
-- Only records meeting the identified invalid-data conditions are removed.
    
DELETE FROM ecommerce_final
WHERE Quantity <= 0
  AND InvoiceNo NOT LIKE 'C%'
  AND NOT (
      UnitPrice = 0
      AND (ProductDescription IS NULL OR TRIM(ProductDescription) = '')
      AND CustomerID IS NULL
  );    


-- Verify that the suspicious records were successfully removed.
-- A result of 0 confirms that no matching invalid records remain.

select count(*) as remaining_suspicious_rows
from ecommerce_final
where Quantity <= 0
  and InvoiceNo not like 'C%'
  and not (
      UnitPrice = 0
      and (ProductDescription is null or trim(ProductDescription) = '')
      and CustomerID is null
  );
  

select count(*) as invalid_price_rows from ecommerce_final
where quantity <= 0;

-- Analyze zero and negative quantity records after cleaning.
-- These records are checked to ensure invalid quantities have been handled.
select 
       sum(case when quantity = 0 then 1 else 0 end) as zero_price_rows,
       sum(case when quantity <= 0 then 1 else 0 end) as negative_price_rows
 from ecommerce_final ;    
 
select
    InvoiceNo,
    StockCode,
    ProductDescription,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
from ecommerce_final
where UnitPrice < 0
order by UnitPrice
limit 50;


-- Group negative-price records by product description
-- to understand what type of transactions they represent.
select
    ProductDescription,
    count(*) as row_count
from ecommerce_final
where UnitPrice < 0
group by ProductDescription
order by row_count desc
limit 30;

select
    sum(case when ProductDescription is null then 1 else 0 end) as null_description_rows,
    sum(case when ProductDescription is not null then 1 else 0 end) as non_null_description_rows
from ecommerce_final
where UnitPrice < 0;

-- Review the actual negative-price records before removing them.
select * from ecommerce_final
where UnitPrice < 0;


-- Remove the identified bad-debt accounting adjustment records
-- because they are not normal product sales.
delete from ecommerce_final
where UnitPrice < 0
  and ProductDescription = 'Adjust bad debt';
  
-- Verify that no negative UnitPrice values remain after cleaning.
select count(*) as remaining_nagative_pricevalues
from ecommerce_final
where UnitPrice < 0; 


-- Count zero-price transactions before removing them.
select count(*) as zero_price_rows
from ecommerce_final
where UnitPrice = 0;

-- Remove zero-price records because they do not represent
-- normal revenue-generating sales for this analysis.
delete from ecommerce_final
where UnitPrice = 0;


-- Verify that zero-price records have been successfully removed.
-- Expected result: 0.
select count(*) as zero_price_rows
from ecommerce_final
where UnitPrice = 0;


-- Perform a final duplicate check after cleaning.
-- A result of 0 rows confirms that no exact duplicate transactions remain.
select
    InvoiceNo,
    StockCode,
    ProductDescription,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    count(*) as duplicate_count
from ecommerce_final
group by
    InvoiceNo,
    StockCode,
    ProductDescription,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
having count(*) > 1
limit 20;


-- Verify the final table structure and confirm that each column
-- has the appropriate data type.
describe ecommerce_final;


-- Identify unnecessary leading or trailing spaces in text columns.
-- TRIM removes unwanted spaces from the beginning and end of text.
select 
    sum(case
        when ProductDescription <> trim(ProductDescription)
        then 1 else 0
    end) as description_extra_spaces,

    sum(case
        when Country <> trim(Country)
        then 1 else 0
    end) as country_extra_spaces
from ecommerce_final;

-- Remove leading and trailing spaces from ProductDescription
-- to standardize the text values.
update ecommerce_final
set ProductDescription = trim(ProductDescription);


-- Verify that unnecessary spaces have been removed.
-- Expected result: 0 extra-space records.
select 
    sum(case
        when ProductDescription <> trim(ProductDescription)
        then 1 else 0
    end) as description_extra_spaces,

    sum(case
        when Country <> trim(Country)
        then 1 else 0
    end) as country_extra_spaces
from ecommerce_final;


-- Count the final number of cleaned records.
select count(*) as total_rows 
from ecommerce_final;


-- Confirm that no zero-price records remain after cleaning.
select count(*) as zero_price_rows 
from ecommerce_final
where unitprice = 0;


-- Confirm that no invalid negative quantities remain
-- outside of cancellation invoices.
select count(*) as negative_quantity_rows
from ecommerce_final
where Quantity < 0
  and InvoiceNo not like 'C%';
  
-- Remove the older version of the cleaned dataset
-- before replacing it with the latest validated data.  
delete from ecommerce_cleaneddata;


-- Copy the fully cleaned and validated data into the final
-- analysis table used for SQL analysis and Power BI.
insert into ecommerce_cleaneddata
select * from ecommerce_final;


-- Verify that the final analysis table contains the expected
-- number of cleaned records.  
select count(*) as cleaned_table_rows
 from ecommerce_cleaneddata  ;
 
 
 /* =========================================================
   E-COMMERCE BUSINESS ANALYSIS
   ========================================================= */
   
   select * from ecommerce_cleaneddata;
   
-- Query 1    
-- Calculate the total revenue generated from all valid transactions.
-- Revenue is calculated as Quantity multiplied by UnitPrice.
select
       sum( quantity * unitprice) as total_revenue
from ecommerce_cleaneddata;

-- Query 2
-- Calculate the total number of unique orders.
-- Each order is identified using a distinct InvoiceNo. 
select
       count(distinct invoiceno) as total_orders
from ecommerce_cleaneddata;   

-- Query 3
-- Calculate the total quantity of products sold.
-- Quantity is summed across all valid transactions.
select 
       sum(quantity) as total_quantity_sold
from ecommerce_cleaneddata ;    

-- Query 4
-- Calculate the average revenue generated per order.
-- Average Order Value is calculated as total revenue divided by unique orders.
select
    round(sum(quantity * unitprice) / count(distinct invoiceno),2) as average_order_value
from ecommerce_cleaneddata;

-- Query 5
-- Calculate the average unit price of products sold.
-- The average is calculated using the UnitPrice column.
select
      avg(unitprice) as average_unit_price
from ecommerce_cleaneddata
where UnitPrice >0;

-- Query 6
-- Calculate the total number of unique customers.
-- Each customer is identified using a distinct CustomerID.
select 
      count(distinct customerid) as total_customers
from ecommerce_cleaneddata
where customerid is not null;
 
-- Query 7
-- Calculate the total number of unique products.
-- Each product is identified using a distinct StockCode. 
select
      count(distinct stockcode) as total_products
from ecommerce_cleaneddata;

-- Query 8
-- Find the highest unit price recorded in the dataset.
-- MAX is used to identify the highest value in the UnitPrice column.
select
      max(unitprice) as highest_unit_price
from ecommerce_cleaneddata where quantity > 0;

-- Query 9
-- Compare the highest unit price from all transactions with valid sales.
-- This helps identify unusually high prices in the dataset.
select
    max(unitprice) as max_price_all_transactions,
    max(case when quantity > 0 then unitprice end) as max_price_sales
from ecommerce_cleaneddata;  

-- Confirmation Query
select * from ecommerce_cleaneddata where UnitPrice = 38970;

-- Query 10
-- Find the lowest unit price recorded for valid sales.
-- MIN is used to identify the lowest value in the UnitPrice column.
select
       min(unitprice) as lowest_unit_price
from ecommerce_cleaneddata
 where quantity >0;
 
 -- Query 11
-- Calculate the total revenue generated by each product.
-- Revenue is grouped by product using StockCode and Description.
 select 
       stockcode,
       productdescription,
       sum(quantity * unitprice) as total_revenue
from ecommerce_cleaneddata  
    where quantity > 0
    group by stockcode , productdescription
    order by total_revenue desc;
    
-- Query 12
-- Identify the top 10 products based on total quantity sold.
-- Products are ranked from highest to lowest quantity sold.
select 
       stockcode ,
       sum(quantity) as total_quantity
from ecommerce_cleaneddata
       group by stockcode
       order by total_quantity desc
       limit 10;
 
-- Query 13
-- Identify the top 10 products based on total revenue.
-- Products are ranked from highest to lowest revenue. 
select
        stockcode ,
        sum( quantity *  unitprice) as total_revenue 
from ecommerce_cleaneddata 
        group by stockcode
        order by total_revenue desc 
        limit 10;       
 
-- Query 14
-- Identify the top 10 customers based on total revenue generated.
-- Customers are ranked from highest to lowest revenue. 
select
	   customerid , 
	   sum(quantity * unitprice) as total_revenue
from ecommerce_cleaneddata
      where customerid is not null    
	   group by customerid
	   order by total_revenue desc
	   limit 10;     

-- Query 15
-- Identify the top 10 customers based on number of orders.
-- Each order is counted using a distinct InvoiceNo.       
select
	  customerid ,
	  count( distinct invoiceno) as number_of_orders
 from ecommerce_cleaneddata
	  where customerid is not null
	  group by customerid
	  order by number_of_orders desc
	  limit 10; 

-- Query 16
-- Calculate the average order value for all customers.
-- Average Order Value is calculated as total revenue divided by unique orders.      
select 
      round( sum(quantity * unitprice) / count(distinct invoiceno) , 2) as average_order_value
from ecommerce_cleaneddata; 


-- Query 17
-- Identify the top 10 countries based on total revenue.
-- Countries are ranked from highest to lowest revenue.
select 
	  country , 
	  sum(quantity * unitprice) as total_revenue
from ecommerce_cleaneddata
	  group by country
	  order by total_revenue desc
	  limit 10;  

-- Query 18
-- Identify the top 10 countries based on total quantity sold.
-- Countries are ranked from highest to lowest quantity sold.      
select 
	  country ,
	  sum(quantity) as total_quantity_sold
from ecommerce_cleaneddata
      group by country
      order by total_quantity_sold desc
      limit 10;      
 
-- Query 19
-- Identify the top 10 countries based on average order value.
-- Average Order Value is calculated using total revenue and unique orders. 
select
	  country ,
      round(sum(quantity * unitprice) / count(distinct invoiceno) ,2) as average_order_value
from ecommerce_cleaneddata
      group by country
      order by average_order_value desc
       limit 10;     
       
-- Query 20
-- Calculate the total revenue generated for each month.
-- Revenue is grouped by year and month to identify monthly sales trends.       
select 
	   year(invoicedate) as year_sales,
       month(invoicedate) as month_sales,
       sum(quantity * unitprice) as total_revenue
from ecommerce_cleaneddata
       group by year_sales , month_sales
       order by total_revenue desc;

-- Query 21
-- Calculate the total number of unique orders for each month.
-- Orders are grouped by year and month to identify monthly order trends.       
select
      year(invoicedate) as year_sales,
      month(invoicedate) as month_sales,
      count(distinct invoiceno) as total_orders
from ecommerce_cleaneddata
      group by year_sales , month_sales
      order by total_orders desc;

-- Query 22
-- Calculate the total quantity of products sold for each month.
-- Quantity is grouped by year and month to identify monthly sales volume.
select 
	  year(invoicedate) as year_sales,
	  month(invoicedate) as month_sales,
	  sum(quantity) as total_quantity
from ecommerce_cleaneddata
	  group by year_sales , month_sales
	  order by total_quantity desc;

-- Query 23
-- Calculate the average order value for each month.
-- Average Order Value is calculated as monthly revenue divided by monthly unique orders.    
select 
	  year(invoicedate) as year_sales,
	  month(invoicedate) as month_sales,
	  sum(quantity * unitprice)/ count(distinct invoiceno) as average_order_value
from ecommerce_cleaneddata
      group by year_sales , month_sales
      order by average_order_value desc;

-- Query 24
-- Calculate the average revenue generated per order for each product.
-- Average revenue per order is calculated using product revenue and unique orders.      
select
	  productdescription ,
      round(sum(quantity * unitprice) / count(distinct invoiceno),2) as average_revenue_per_order
from ecommerce_cleaneddata
	  group by productdescription
      order by average_revenue_per_order desc;

-- Query 25
-- Calculate the average quantity of products purchased per order for each country.
-- Average quantity per order is calculated as total quantity divided by unique orders.      
select
	  country,
	  round(sum(quantity) /  count(distinct invoiceno),2) as average_quantity_per_order
from ecommerce_cleaneddata
	  group by country
	  order by average_quantity_per_order desc;        
      
