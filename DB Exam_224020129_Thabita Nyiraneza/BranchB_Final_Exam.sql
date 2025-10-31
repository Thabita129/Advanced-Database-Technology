
--Thabita NYIRANEZA
--Reg No: 224020129
--Advanced Database Technology Final Exam

--Branch B database: OperationsDB

-- 1. Bid Table
CREATE TABLE Bid (
    BidID SERIAL PRIMARY KEY,
    SupplierID INT,
    RequestID INT,
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    DeliveryDays INT CHECK (DeliveryDays > 0),
    Decision VARCHAR(20) CHECK (Decision IN ('Pending', 'Approved', 'Rejected'))
);

-- 2. PurchaseOrder Table
CREATE TABLE PurchaseOrder (
    OrderID SERIAL PRIMARY KEY,
    BidID INT UNIQUE,
    OrderDate DATE NOT NULL,
    Quantity INT CHECK (Quantity > 0),
    TotalAmount NUMERIC(12,2) CHECK (TotalAmount > 0)
);

-- 3. Delivery Table
CREATE TABLE Delivery (
    DeliveryID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE,
    DeliveryDate DATE,
    Status VARCHAR(20) CHECK (Status IN ('Pending', 'Delivered', 'Rejected')),
    ReceivedBy VARCHAR(100)
);

-- 4. Payment Table
CREATE TABLE Payment (
    PaymentID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE,
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    PaymentDate DATE,
    Method VARCHAR(30) CHECK (Method IN ('Cash', 'BankTransfer', 'Cheque'))
);

-- Sample data
INSERT INTO Bid (SupplierID, RequestID, Amount, DeliveryDays, Decision)
VALUES
(1, 1, 500000, 7, 'Approved'),
(2, 2, 300000, 10, 'Pending'),
(3, 3, 400000, 9, 'Pending');

SELECT * FROM Bid

INSERT INTO PurchaseOrder (BidID, OrderDate, Quantity, TotalAmount)
VALUES
(1, '2025-10-10', 5, 2500000),
(2, '2025-10-15', 5, 1500000);

INSERT INTO Delivery (DeliveryID, DeliveryDate, Status, ReceivedBy)
VALUES
(1, '2025-10-20', 'Delivered', 'John Doe');

INSERT INTO Payment (OrderID, Amount, PaymentDate, Method)
VALUES
(1, 2500000, '2025-10-16', 'BankTransfer'),
(2, 1500000, '2025-10-22', 'BankTransfer');

SELECT * FROM Payment
--------------------------------------------------------------------------------------------
-- A2: Create a database link between two schemas. 
-- Demonstrate a successful remote SELECT and a distributed join between local and remote tables

-- 2. 1 database link
-- to allow to both two databases to communicate we use Foreign Data Wrapper(FDW) 
-- FDW enable access to tables in another database as if they were local
-- FDW stores metadata about how to access the remote table and actual data remains in the remote database

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create a foreign server (This defines the connection to E-procurement)
CREATE SERVER connect_branchba
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'localhost',       -- host where E-procurement is running
    dbname 'E-Procurement BranchA',  -- remote db to connect to
    port '5432'
);

-- create a user mapping to remote credentials on ProcurementDB

CREATE USER MAPPING IF NOT EXISTS FOR postgres  
SERVER connect_branchba
OPTIONS (
    user 'postgres',         -- ProcurementDB username
    password '1234'       -- ProcurementDB password
);
  
-- Import the two ProcurementDB tables as foreign tables in OperationsDB
IMPORT FOREIGN SCHEMA public
LIMIT TO (Supplier, Purchaserequest)
FROM SERVER connect_branchba INTO public;


-- 2.2 Demostrate a distributed join between local and remote tables
-- run in OperationsDB
SELECT b.bidid, b.amount, s.name AS supplier_name, pr.department
FROM bid b
JOIN supplier s ON b.supplierid = s.supplierid
JOIN purchaserequest pr ON b.requestid = pr.requestid
WHERE b.decision = 'Approved';
----------------------------------------------------------------------------
--A3: Parallel Query Execution and Compare Serial vs Parallel Query Plans

-- 3.1 Enable parallelism
SET max_parallel_workers_per_gather = 4;   -- Default is 2
SET parallel_setup_cost = 0;               -- default is 1000; Reduce threshold for using parallel
SET parallel_tuple_cost = 0;               -- Encourage parallel plans
SET min_parallel_table_scan_size = '8MB';
SET min_parallel_index_scan_size = '8MB';

-- 3.2. Compare Serial vs Parallel Query Plans

-- 3.2.1 Serial Query Plans: force no parallel workers
-- and then analyze query execution plan
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT SupplierId, AVG(totalamount) AS avg_order_value
FROM PurchaseOrder
GROUP BY SupplierId
ORDER BY avg_order_value DESC
LIMIT 10;

-- Parallel Query Execution
-- to achieven this set worker to a number great that 2 which is the default one
-- and then analyze query execution plan and compare the result with serial

SET max_parallel_workers_per_gather = 4;
EXPLAIN ANALYZE
SELECT SupplierId, AVG(totalamount) AS avg_order_value
FROM PurchaseOrder
GROUP BY SupplierId
ORDER BY avg_order_value DESC
LIMIT 10;
-----------------------------------------------------------------------------------

--A4 — Two-Phase Commit Simulation (2PC) — distributed transaction insert & commit once
-- Write a PL/SQL block performing inserts on both nodes and committing once
-- In this section we are going to simulate two phase commit 
-- inserts data on both nodes and committing once. Verify atomicity
-- let create a PL block that create a shipments and then report its corresponding payment
-- the whole operation is atomic which mean the operation will be full completed or not compelete at all in case anything goes wrong

DO $$
DECLARE
    -- Define variable to store the new BidId generated by the local insert
    local_Bid_Id INT;
	
	-- 1. Start local transaction
BEGIN;
-- insert local change
INSERT INTO Bid (SupplieId, RequestId, Amount, Deliverydays, Decision)
VALUES (1, 1, 250000, 7, 'Pending')
RETURNING BidId INTO STRICT local_Bid_Id; 

-- Log the newly generated shipment_id for debugging
 RAISE NOTICE 'New Bid_Id = %', local_Bid_Id;

-- 2. Prepare local transaction (give it a GID)
PREPARE TRANSACTION 'local_gid_1001';
-- At this point the local tx is prepared but not committed.

-- 3. On remote (ProcurementDB) we should also PREPARE a transaction that makes a related change.
-- Use dblink to execute a remote BEGIN/INSERT/PREPARE
SELECT dblink_exec(
  'host=localhost dbname=ProcurementDB user=postgres password=postgres',
  $sql$
    BEGIN;
    INSERT INTO some_remote_table (...) VALUES (...);
    PREPARE TRANSACTION 'remote_gid_1001';
  $sql$
);

-- TASK 5: Simulate a remote failure during a distributed transaction. Check unresolved transactions and resolve them using ROLLBACK FORCE

-- 5.1 Simulate a remote failure during a distributed transaction
-- transaction in postgres should be either commited or rolled back automatically
-- to allow manually commit/rollback of transaction which must prepared transaction
-- by default prepared transaction are disable in postgers, therefore to enable this
-- functionality we are required to change max_prepared_transactions config varibale to a value >0 and then restart the server
-- confirm change has reflected by running : SHOW max_prepared_transactions;
-- prepared statement keep transactions in prepared state for manual resolution

-- 5. 1 remote failure is being simulated by inserting 
-- into wrong table from local node(invalid_payment)

-- show prepared (in-doubt) transactions
SELECT * FROM pg_prepared_xacts;

-- Suppose you see a GID 'remote_gid_1001', you can:
ROLLBACK PREPARED 'remote_gid_1001';
-- or to commit:
-- COMMIT PREPARED 'remote_gid_1001';

--Task 6 — Distributed Concurrency Control (lock conflict demo)
--You will simulate two sessions updating the same row. One session acquires lock; the other waits — that’s a lock conflict.
--How to demo (manual, two sessions required)

--1.	Open psql session A, connect to OperationsDB:
BEGIN;
UPDATE purchaseorder SET totalamount = totalamount WHERE orderid = 1;  -- locks the row
-- do NOT commit

--2.Open psql session B (another terminal), connect to OperationsDB and run:
UPDATE purchaseorder SET totalamount = totalamount + 1 WHERE orderid = 1;
-- This will block/wait until session A commits or rollbacks.

--3.In session A, COMMIT or ROLLBACK to release lock; session B will then proceed.
--To see locks and waiting processes:
--Run in any session:
-- show blocking and waiting
SELECT pid, usename, state, query_start, query FROM pg_stat_activity WHERE state <> 'idle';
-- show locks
SELECT t.relname, l.locktype, l.mode, l.granted, a.query, a.pid
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
LEFT JOIN pg_class t ON l.relation = t.oid
ORDER BY a.query_start DESC;

--Task 7 — Parallel Data Loading / ETL Simulation
--For large loads, Postgres supports COPY for fastest loading. ETL strategies may use parallel COPY into partitioned tables or use parallel workers for queries post-load.
--SQL — example: load sample big table with COPY and show parallel aggregation

-- Create a staging table to import many payment rows
CREATE TABLE IF NOT EXISTS payments_staging (
  paymentid SERIAL PRIMARY KEY,
  orderid INT,
  amount NUMERIC(12,2),
  paymentdate DATE,
  method VARCHAR(30)
);

SET max_parallel_workers_per_gather = 4;
EXPLAIN ANALYZE
SELECT method, SUM(amount) FROM payments_staging GROUP BY method;

--A5 — Distributed Query Optimization 
--We need to analyze a distributed join and explain optimizer choices.
--SQL — use EXPLAIN (ANALYZE, VERBOSE)
-- Assuming 'supplier' and 'purchaserequest' are foreign tables imported from ProcurementDB

SELECT po.orderid, s.name, pr.department, po.totalamount
FROM purchaseorder po
JOIN bid b ON po.bidid = b.bidid
JOIN supplier s ON b.supplierid = s.supplierid
JOIN purchaserequest pr ON b.requestid = pr.requestid
ORDER BY po.totalamount DESC
LIMIT 10;

--Task 10 — Performance Benchmark & Report (EXPLAIN ANALYZE comparisons)
--we must run a representative query in three modes and record times. For Postgres we compare:
--•	single-node (local) execution (all data co-located),
--•	parallel execution (multiple workers),
--•	distributed (joining with foreign tables).

-- 1) Centralized version (simulate if all tables local) - run on single DB copy
SET max_parallel_workers_per_gather = 0;  -- no parallel
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.name, COUNT(po.orderid) AS orders_count
FROM supplier s
JOIN bid b ON s.supplierid = b.supplierid
JOIN purchaseorder po ON b.bidid = po.bidid
GROUP BY s.name
ORDER BY orders_count DESC
LIMIT 10;

-- 2) Parallel version (intra-node parallelism)
SET max_parallel_workers_per_gather = 8;
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.name, COUNT(po.orderid) AS orders_count
FROM supplier s
JOIN bid b ON s.supplierid = b.supplierid
JOIN purchaseorder po ON b.bidid = po.bidid
GROUP BY s.name
ORDER BY orders_count DESC
LIMIT 10;

-- 3) Distributed version (supplier is foreign table via FDW)
-- ensure supplier is foreign table in this DB (imported earlier)
SET max_parallel_workers_per_gather = 4;
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.name, COUNT(po.orderid) AS orders_count
FROM supplier s  -- if supplier is foreign, this will fetch remote data
JOIN bid b ON s.supplierid = b.supplierid
JOIN purchaseorder po ON b.bidid = po.bidid
GROUP BY s.name
ORDER BY orders_count DESC
LIMIT 10;


--SECTION B
--B1 Declarative Rules Hardening
-- 1️ Add NOT NULL and domain CHECK constraints
ALTER TABLE PurchaseOrder
    ALTER COLUMN OrderDate SET NOT NULL,
    ALTER COLUMN Quantity SET NOT NULL,
    ALTER COLUMN TotalAmount SET NOT NULL;

ALTER TABLE PurchaseOrder
    ADD CONSTRAINT chk_po_total CHECK (TotalAmount > 0),
    ADD CONSTRAINT chk_po_quantity CHECK (Quantity > 0);

ALTER TABLE Payment
    ALTER COLUMN PaymentDate SET NOT NULL,
    ALTER COLUMN Amount SET NOT NULL,
    ALTER COLUMN Method SET NOT NULL;

ALTER TABLE Payment
    ADD CONSTRAINT chk_pay_amount CHECK (Amount > 0),
    ADD CONSTRAINT chk_pay_method CHECK (Method IN ('Cash', 'BankTransfer', 'Cheque'));

--B7: E–C–A Trigger for Denormalized Totals

--Step 1 — Create the Audit Table
CREATE TABLE PurchaseOrder_AUDIT (
    audit_id SERIAL PRIMARY KEY,
    bef_total NUMERIC(12,2),
    aft_total NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    key_col VARCHAR(64)
);
--Step 2 — Create the Trigger Function
CREATE OR REPLACE FUNCTION fn_update_order_totals()
RETURNS TRIGGER AS $$
DECLARE
    affected_orders RECORD;
    old_total NUMERIC(12,2);
    new_total NUMERIC(12,2);
BEGIN
    -- Find all distinct OrderIDs affected by the Payment DML operation
    FOR affected_orders IN
        SELECT DISTINCT OrderID FROM Payment
    LOOP
        SELECT COALESCE(SUM(Amount), 0) INTO new_total
        FROM Payment
        WHERE OrderID = affected_orders.OrderID;

        SELECT TotalAmount INTO old_total
        FROM PurchaseOrder
        WHERE OrderID = affected_orders.OrderID;

        -- Update PurchaseOrder total
        UPDATE PurchaseOrder
        SET TotalAmount = new_total
        WHERE OrderID = affected_orders.OrderID;

        -- Log to the audit table
        INSERT INTO PurchaseOrder_AUDIT (bef_total, aft_total, key_col)
        VALUES (old_total, new_total, affected_orders.OrderID::TEXT);
    END LOOP;

--Step 3 — Create the Trigger
--Now attach the function to the Payment table.

CREATE TRIGGER trg_payment_update_totals
AFTER INSERT OR UPDATE OR DELETE ON Payment
REFERENCING OLD TABLE AS old_payments NEW TABLE AS new_payments
FOR EACH STATEMENT
EXECUTE FUNCTION fn_update_order_totals();

    RETURN NULL; -- statement-level triggers return NULL
END;
$$ LANGUAGE plpgsql;

--B8: Recursive Hierarchy Roll-Up

--1. Create the HIER Table
CREATE TABLE HIER (
    parent_id VARCHAR(50),
    child_id  VARCHAR(50),
    label     VARCHAR(100)
);

--2. Insert Sample Hierarchical Data
INSERT INTO HIER (parent_id, child_id, label) VALUES
('ROOT', 'PROCUREMENT', 'All Procurement Activities'),
('PROCUREMENT', 'PURCHASE_ORDER', 'Purchase Orders'),
('PROCUREMENT', 'PAYMENT', 'Payments'),
('PURCHASE_ORDER', 'LOCAL_ORDER', 'Local Purchase Orders'),
('PURCHASE_ORDER', 'INTERNATIONAL_ORDER', 'International Purchase Orders'),
('PAYMENT', 'CASH_PAYMENT', 'Cash Transactions'),
('PAYMENT', 'BANK_PAYMENT', 'Bank Transfers');

--3. Recursive Query to Find Root and Depth
WITH RECURSIVE hierarchy_path AS (
    --  Anchor: start from every child node
    SELECT 
        child_id,
        parent_id,
        parent_id AS root_id,
        1 AS depth
    FROM HIER
    WHERE parent_id = 'ROOT'
    
    UNION ALL

    -- Recursive step: find deeper levels
    SELECT 
        h.child_id,
        h.parent_id,
        hp.root_id,
        hp.depth + 1
    FROM HIER h
    JOIN hierarchy_path hp ON h.parent_id = hp.child_id
)
SELECT 
    child_id,
    root_id,
    depth
FROM hierarchy_path
ORDER BY depth, child_id;

--B9: Mini-Knowledge Base with Transitive Inference
--Step 1 — Create the TRIPLE Table
--A triple represents one fact in the form (subject, predicate, object) — sometimes written as (s, p, o).
CREATE TABLE TRIPLE (
    s VARCHAR(64),
    p VARCHAR(64),
    o VARCHAR(64)
);

--Step 2 — Insert 8–10 Domain Facts (Procurement Context)
--Each row expresses a relationship or rule between entities.
INSERT INTO TRIPLE (s, p, o) VALUES
('Supplier', 'isA', 'BusinessEntity'),
('PurchaseRequest', 'isA', 'ProcurementActivity'),
('Bid', 'isA', 'ProcurementActivity'),
('PurchaseOrder', 'isA', 'ProcurementActivity'),
('Payment', 'isA', 'FinancialTransaction'),
('FinancialTransaction', 'isA', 'ProcurementActivity'),
('Delivery', 'isA', 'FulfillmentStep'),
('FulfillmentStep', 'isA', 'ProcurementActivity'),
('LatePayment', 'implies', 'SupplierAlert'),
('SupplierAlert', 'implies', 'Investigation');

--Step 3 — Recursive Query for Transitive isA* Inference

WITH RECURSIVE isA_chain AS (
    --  Base case: direct "isA" relationships
    SELECT s AS child, o AS ancestor
    FROM TRIPLE
    WHERE p = 'isA'
    
    UNION ALL
    
    --  Recursive step: if X isA Y and Y isA Z, then X isA Z
    SELECT ic.child, t.o AS ancestor
    FROM isA_chain ic
    JOIN TRIPLE t ON ic.ancestor = t.s
    WHERE t.p = 'isA'
)
SELECT * FROM isA_chain
ORDER BY child, ancestor;

--B10: Business Limit Alert (Function + Trigger) (row-budget safe)

--Step 1 — Create the BUSINESS_LIMITS Table
CREATE TABLE BUSINESS_LIMITS (
    rule_key VARCHAR(64) PRIMARY KEY,
    threshold NUMERIC(12,2),
    active CHAR(1) CHECK (active IN ('Y','N'))

INSERT INTO BUSINESS_LIMITS (rule_key, threshold, active)
VALUES ('MAX_DAILY_PAYMENT', 50000, 'Y');

--FUNCTION

CREATE OR REPLACE FUNCTION fn_should_alert(p_orderid INT, p_amount NUMERIC, p_date DATE)
RETURNS INT AS $$
DECLARE
    v_threshold NUMERIC;
    v_total NUMERIC;
BEGIN
    -- Fetch active rule
    SELECT threshold INTO v_threshold
    FROM BUSINESS_LIMITS
    WHERE rule_key = 'MAX_DAILY_PAYMENT' AND active = 'Y';

    IF v_threshold IS NULL THEN
        RETURN 0; -- no active rule, skip
    END IF;

    -- Sum of payments made today (before inserting new one)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total
    FROM Payment
    WHERE paymentdate = p_date;

    -- Check if new payment exceeds threshold
    IF (v_total + p_amount) > v_threshold THEN
        RETURN 1; -- violation
    ELSE
        RETURN 0; -- okay
    END IF;
END;
$$ LANGUAGE plpgsql;




























