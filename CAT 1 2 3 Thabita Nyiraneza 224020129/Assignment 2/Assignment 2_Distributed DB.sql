-- ============================================================
-- E-PROCUREMENT DISTRIBUTED DATABASE SCRIPT
-- Two-node distributed setup:
--  - ProcurementDB (Supplier, PurchaseRequest)
--  - OperationsDB  (Bid, PurchaseOrder, Delivery, Payment)
--
-- Includes:
--  - Schema creation + sample data
--  - postgres_fdw & dblink setup
--  - Foreign server & user mapping
--  - Import of remote tables
--  - Cross-node referential triggers (using dblink)
--  - Distributed inserts via dblink (simulate 2PC)
--  - Prepared transaction inspection / forced rollback
--  - Lock conflict demo between nodes via dblink
--  - Parallel vs serial EXPLAINs and benchmarks
-- ============================================================

-- =====================================================================
-- NOTE: Run these commands from a superuser session (psql or pgAdmin)
-- Adjust 'host', 'user', 'password', and 'port' options to match your setup.
-- =====================================================================

-- ---------------------------
-- 1) Create the two databases
-- ---------------------------
-- (Run these from the initial connection to 'postgres' or any admin DB)

DROP DATABASE IF EXISTS ProcurementDB;
DROP DATABASE IF EXISTS OperationsDB;

CREATE DATABASE ProcurementDB;
CREATE DATABASE OperationsDB;

-- ---------------------------
-- 2) Create schema in ProcurementDB
--    (ProcurementDB handles Supplier & PurchaseRequest)
-- ---------------------------

\c ProcurementDB

-- Enable dblink/FDW extensions on procurement if needed later
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Supplier table
CREATE TABLE IF NOT EXISTS Supplier (
    SupplierID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Contact VARCHAR(50),
    Email VARCHAR(100) UNIQUE,
    Rating NUMERIC(3,2) CHECK (Rating >= 0 AND Rating <= 5)
);

-- PurchaseRequest table
CREATE TABLE IF NOT EXISTS PurchaseRequest (
    RequestID SERIAL PRIMARY KEY,
    Department VARCHAR(100) NOT NULL,
    RequestedBy VARCHAR(100) NOT NULL,
    DateRequested DATE NOT NULL,
    Status VARCHAR(20) CHECK (Status IN ('Pending','Approved','Rejected'))
);

-- Sample data for ProcurementDB
INSERT INTO Supplier (Name, Contact, Email, Rating)
VALUES
('ABC Supplies Ltd', '0788888888', 'abc@supplies.com', 4.5),
('QuickSource Co', '0799999999', 'quick@source.com', 4.2),
('RwandaTrade', '0722222222', 'info@rwandatrade.com', 3.8)
ON CONFLICT DO NOTHING;

INSERT INTO PurchaseRequest (Department, RequestedBy, DateRequested, Status)
VALUES
('IT', 'John Doe', '2025-10-01', 'Pending'),
('Finance', 'Mary Umutoni', '2025-10-02', 'Approved'),
('HR', 'Alice Iradukunda', '2025-10-03', 'Approved'),
('Procurement', 'David Niyonzima', '2025-10-04', 'Pending'),
('Operations', 'Samuel Habimana', '2025-10-05', 'Approved')
ON CONFLICT DO NOTHING;

-- Quick check
SELECT 'ProcurementDB Supplier count' AS info, count(*) FROM Supplier;
SELECT 'ProcurementDB PurchaseRequest count' AS info, count(*) FROM PurchaseRequest;


-- ---------------------------
-- 3) Create schema in OperationsDB
--    (OperationsDB holds Bid, PurchaseOrder, Delivery, Payment)
-- ---------------------------

\c OperationsDB

CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Bid table (references suppliers & requests logically)
CREATE TABLE IF NOT EXISTS Bid (
    BidID SERIAL PRIMARY KEY,
    SupplierID INT,    -- refers to ProcurementDB.Supplier.SupplierID (logical FK)
    RequestID INT,     -- refers to ProcurementDB.PurchaseRequest.RequestID (logical FK)
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    DeliveryDays INT CHECK (DeliveryDays > 0),
    Decision VARCHAR(20) CHECK (Decision IN ('Pending','Approved','Rejected'))
);

-- PurchaseOrder table (1:1 with Bid)
CREATE TABLE IF NOT EXISTS PurchaseOrder (
    OrderID SERIAL PRIMARY KEY,
    BidID INT UNIQUE,  -- refers to Bid(BidID)
    OrderDate DATE NOT NULL,
    Quantity INT CHECK (Quantity > 0),
    TotalAmount NUMERIC(12,2) CHECK (TotalAmount > 0)
);

-- Delivery table (1:1 with PurchaseOrder)
CREATE TABLE IF NOT EXISTS Delivery (
    DeliveryID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE, -- refers to PurchaseOrder(OrderID)
    DeliveryDate DATE,
    Status VARCHAR(20) CHECK (Status IN ('Pending','Delivered','Rejected')),
    ReceivedBy VARCHAR(100)
);

-- Payment table (1:1 with PurchaseOrder)
CREATE TABLE IF NOT EXISTS Payment (
    PaymentID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE, -- refers to PurchaseOrder(OrderID)
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    PaymentDate DATE,
    Method VARCHAR(30) CHECK (Method IN ('Cash','BankTransfer','Cheque'))
);

-- Sample data for OperationsDB
INSERT INTO Bid (SupplierID, RequestID, Amount, DeliveryDays, Decision)
VALUES
(1, 1, 500000, 10, 'Pending'),
(2, 2, 300000, 8, 'Approved'),
(3, 3, 400000, 9, 'Pending')
ON CONFLICT DO NOTHING;

INSERT INTO PurchaseOrder (BidID, OrderDate, Quantity, TotalAmount)
VALUES
(2, '2025-10-10', 5, 1500000) -- Order created from approved bid(2)
ON CONFLICT DO NOTHING;

INSERT INTO Delivery (OrderID, DeliveryDate, Status, ReceivedBy)
VALUES
(1, '2025-10-15', 'Delivered', 'John Doe')
ON CONFLICT DO NOTHING;

INSERT INTO Payment (OrderID, Amount, PaymentDate, Method)
VALUES
(1, 1500000, '2025-10-16', 'BankTransfer')
ON CONFLICT DO NOTHING;

-- Quick check
SELECT 'OperationsDB Bid count' AS info, count(*) FROM Bid;
SELECT 'OperationsDB PurchaseOrder count' AS info, count(*) FROM PurchaseOrder;


-- ---------------------------
-- 4) Setup FDW connectivity between the two DBs
--    We'll create a SERVER in OperationsDB that connects to ProcurementDB
--    and a server in ProcurementDB that can connect to OperationsDB (if needed).
-- ---------------------------

\c OperationsDB

-- Create FDW extension (already done above) and foreign server for ProcurementDB
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- If server exists drop and recreate to avoid duplicates
DROP SERVER IF EXISTS procurement_server CASCADE;

CREATE SERVER procurement_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'ProcurementDB', port '5432');

-- Create user mapping FROM local user (postgres) to remote ProcurementDB credentials
-- Adjust remote user/password as needed for your environment
CREATE USER MAPPING IF NOT EXISTS FOR postgres
SERVER procurement_server
OPTIONS (user 'postgres', password 'postgres');

-- IMPORT foreign tables (optional: you can import only Supplier & PurchaseRequest)
-- This will create foreign tables in OperationsDB that point to ProcurementDB.public.Supplier etc.
-- If you prefer not to import, you can use dblink queries instead.
IMPORT FOREIGN SCHEMA public
LIMIT TO (supplier, purchaserequest)
FROM SERVER procurement_server INTO public;


-- Verify the foreign tables are visible in OperationsDB:
-- They should appear as foreign tables 'supplier' and 'purchaserequest' (lowercase)
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_name IN ('supplier','purchaserequest')
ORDER BY table_name;

-- ---------------------------
-- 5) Cross-node referential integrity enforcement (trigger)
--    When inserting a Bid in OperationsDB, ensure the SupplierID and RequestID exist in ProcurementDB.
--    We'll use dblink to check remote existence.
-- ---------------------------

-- Create function to enforce supplier & request existence via dblink
CREATE OR REPLACE FUNCTION enforce_supplier_and_request_fk()
RETURNS TRIGGER AS $$
DECLARE
    supplier_exists BOOL;
    request_exists BOOL;
    -- connection string to ProcurementDB (use same creds as USER MAPPING or change)
    conn TEXT := 'host=localhost dbname=ProcurementDB user=postgres password=postgres port=5432';
BEGIN
    -- Check Supplier existence
    SELECT EXISTS (
        SELECT 1 FROM dblink(conn, format('SELECT 1 FROM Supplier WHERE SupplierID = %L', NEW.SupplierID))
        AS t(exists_flag int)
    ) INTO supplier_exists;

    IF NOT supplier_exists THEN
        RAISE EXCEPTION 'Foreign key violation: Supplier % does not exist in ProcurementDB', NEW.SupplierID;
    END IF;

    -- Check PurchaseRequest existence
    SELECT EXISTS (
        SELECT 1 FROM dblink(conn, format('SELECT 1 FROM PurchaseRequest WHERE RequestID = %L', NEW.RequestID))
        AS t(exists_flag int)
    ) INTO request_exists;

    IF NOT request_exists THEN
        RAISE EXCEPTION 'Foreign key violation: PurchaseRequest % does not exist in ProcurementDB', NEW.RequestID;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to Bid table
DROP TRIGGER IF EXISTS trg_enforce_bid_fk ON Bid;
CREATE TRIGGER trg_enforce_bid_fk
BEFORE INSERT OR UPDATE ON Bid
FOR EACH ROW
EXECUTE FUNCTION enforce_supplier_and_request_fk();


-- ---------------------------
-- 6) Simulate cascade-delete behavior across nodes:
--    If a Supplier is deleted from ProcurementDB, delete related Bids in OperationsDB via dblink_exec.
-- ---------------------------

\c ProcurementDB

-- Create function that calls dblink to delete bids in OperationsDB when a Supplier is removed
CREATE OR REPLACE FUNCTION cascade_delete_bids_in_operations()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM dblink_exec(
        'host=localhost dbname=OperationsDB user=postgres password=postgres port=5432',
        'DELETE FROM Bid WHERE SupplierID = ' || OLD.SupplierID
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger on ProcurementDB.Supplier
DROP TRIGGER IF EXISTS trg_cascade_delete_bid ON Supplier;
CREATE TRIGGER trg_cascade_delete_bid
AFTER DELETE ON Supplier
FOR EACH ROW
EXECUTE FUNCTION cascade_delete_bids_in_operations();


-- ---------------------------
-- 7) Demonstrate distributed join (OperationsDB joins local Bid with remote Supplier)
-- ---------------------------

\c OperationsDB

-- Example: Get approved bids along with supplier info from ProcurementDB via foreign table (imported) or dblink
-- If the foreign table was imported (IMPORT FOREIGN SCHEMA), you can simply query it:
SELECT b.BidID, b.Amount, b.DeliveryDays, s.Name AS SupplierName, s.Email, s.Rating
FROM Bid b
JOIN supplier s ON b.SupplierID = s.SupplierID  -- 'supplier' is a foreign table mapped to ProcurementDB.Supplier
WHERE b.Decision = 'Approved';

-- If you didn't import foreign tables, use dblink:
-- SELECT b.BidID, b.Amount, b.DeliveryDays, s.name, s.email, s.rating
-- FROM Bid b
-- JOIN LATERAL (
--   SELECT name, email, rating
--   FROM dblink('dbname=ProcurementDB host=localhost user=postgres password=postgres',
--               format('SELECT name, email, rating FROM Supplier WHERE SupplierID = %L', b.SupplierID))
--       AS s(name text, email text, rating numeric)
-- ) s ON true
-- WHERE b.Decision = 'Approved';


-- ---------------------------
-- 8) Parallelism: compare serial vs parallel plans on an aggregating query (on OperationsDB)
-- ---------------------------

-- Ensure server allows parallelism and adjust parameters as needed.
-- (In real servers these would be set in postgresql.conf for persistent effect)
SET max_parallel_workers_per_gather = 4;
SET parallel_setup_cost = 0;
SET parallel_tuple_cost = 0;
SET min_parallel_table_scan_size = '8MB';
SET min_parallel_index_scan_size = '8MB';

-- Serial plan (disable parallel)
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT SupplierID, AVG(TotalAmount) AS avg_order_value
FROM PurchaseOrder
GROUP BY SupplierID
ORDER BY avg_order_value DESC
LIMIT 10;

-- Parallel plan (enable parallel)
SET max_parallel_workers_per_gather = 4;
EXPLAIN ANALYZE
SELECT SupplierID, AVG(TotalAmount) AS avg_order_value
FROM PurchaseOrder
GROUP BY SupplierID
ORDER BY avg_order_value DESC
LIMIT 10;


-- ---------------------------
-- 9) Two-phase commit simulation & distributed insert (DO block)
--    We'll insert a Bid locally (OperationsDB) and create a corresponding Payment in ProcurementDB (remote)
--    Using dblink_exec we simulate remote action; note: true 2PC across two separate Postgres servers requires prepared transactions.
-- ---------------------------

-- Important: to use PREPARE TRANSACTION you must set max_prepared_transactions > 0 in postgresql.conf and restart server.

-- DO block that inserts in OperationsDB and calls dblink to insert in ProcurementDB (remote payments table simulated there)
DO $$
DECLARE
    new_bid_id INT;
    remote_sql TEXT;
BEGIN
    -- Insert a new bid in OperationsDB
    INSERT INTO Bid (SupplierID, RequestID, Amount, DeliveryDays, Decision)
    VALUES (1, 1, 250000, 7, 'Pending')
    RETURNING BidID INTO new_bid_id;

    RAISE NOTICE 'Inserted new Bid ID = %', new_bid_id;

    -- Prepare remote insert (for demonstration we insert into Payment table on ProcurementDB)
    remote_sql := format($sql$
        INSERT INTO Payment (OrderID, Amount, PaymentDate, Method)
        VALUES (NULL, %L, CURRENT_DATE, 'BankTransfer');
    $sql$, 250000);

    PERFORM dblink_exec(
        'host=localhost dbname=ProcurementDB user=postgres password=postgres port=5432',
        remote_sql
    );

    RAISE NOTICE 'Remote insert executed via dblink.';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Distributed insert failed: %', SQLERRM;
    RAISE;
END
$$ LANGUAGE plpgsql;


-- ---------------------------
-- 10) Simulate a remote failure in a distributed transaction and inspect prepared transactions
-- ---------------------------

-- We'll simulate a remote failure by executing a dblink_exec that PREPAREs a transaction on the remote side
-- but then we intentionally fail and must roll it back manually.
-- NOTE: This requires max_prepared_transactions > 0 and a restart.

-- Example DO block to PREPARE a remote transaction
DO $$
DECLARE
    local_bid_id INT;
    local_gid TEXT;
    remote_gid TEXT;
    remote_sql TEXT;
BEGIN
    -- Local insert
    INSERT INTO Bid (SupplierID, RequestID, Amount, DeliveryDays, Decision)
    VALUES (2, 2, 111111, 5, 'Pending')
    RETURNING BidID INTO local_bid_id;

    -- prepare unique GIDs
    local_gid := format('local_bid_tx_%s', local_bid_id);
    remote_gid := format('remote_payment_tx_%s', local_bid_id);

    RAISE NOTICE 'Local bid id = %, local_gid = %, remote_gid = %', local_bid_id, local_gid, remote_gid;

    -- Attempt to execute remote PREPARED transaction (simulate remote prepare)
    -- remote_sql: begin; insert ...; prepare transaction 'remote_gid';
    remote_sql := format($r$
        BEGIN;
        INSERT INTO Payment(orderid, amount, paymentdate, method)
        VALUES (NULL, %L, CURRENT_DATE, 'Cash');
        PREPARE TRANSACTION %L;
    $r$, 111111, remote_gid);

    BEGIN
        PERFORM dblink_exec(
            'dbname=ProcurementDB host=localhost user=postgres password=postgres port=5432',
            remote_sql
        );
        RAISE NOTICE 'Remote PREPARE executed.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Simulated remote failure during PREPARE: %', SQLERRM;
    END;

    -- Note: local transaction is still unprepared; this block ends without preparing local transaction.
END;
$$ LANGUAGE plpgsql;

-- After simulation, inspect prepared transactions on either node
\c ProcurementDB
SELECT * FROM pg_prepared_xacts;

\c OperationsDB
SELECT * FROM pg_prepared_xacts;

-- Force rollback of a prepared GID if present (example GID name must match an actual prepared GID)
-- ROLLBACK PREPARED 'remote_payment_tx_...';
-- ROLLBACK PREPARED 'local_bid_tx_...';

-- ---------------------------
-- 11) Check unresolved prepared transactions (utility DO block)
-- ---------------------------

\c OperationsDB

DO $$
DECLARE
    tx RECORD;
BEGIN
    RAISE NOTICE 'Listing prepared transactions on this DB:';
    FOR tx IN
        SELECT gid, database, owner, prepared
        FROM pg_prepared_xacts
        ORDER BY prepared DESC
    LOOP
        RAISE NOTICE 'GID=% | DB=% | Owner=% | Prepared=%', tx.gid, tx.database, tx.owner, tx.prepared;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------
-- 12) Demonstrate lock conflict between two nodes using dblink
--     Start a local transaction that updates a row and then from another session attempt to update same row via dblink.
-- ---------------------------

-- INSTRUCTIONS:
-- 1) In psql session A (OperationsDB) run:
--    BEGIN;
--    UPDATE PurchaseOrder SET TotalAmount = TotalAmount WHERE OrderID = 1;
--    -- don't commit yet, leave transaction open
--
-- 2) In session B run the following (OperationsDB), it will hang/wait until session A commits or rollbacks:
--    SELECT dblink_exec('dbname=OperationsDB host=localhost user=postgres password=postgres',
--                       $sql$ UPDATE PurchaseOrder SET TotalAmount = TotalAmount + 1 WHERE OrderID = 1; $sql$);

-- To demo within single script is not possible — follow the two-session steps above.

-- ---------------------------
-- 13) Distributed Query Optimization & Benchmarking
--     EXPLAIN ANALYZE for distributed join across imported foreign table
-- ---------------------------

\c OperationsDB

-- Example distributed join: local PurchaseOrder joined with remote Supplier via imported foreign table 'supplier'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT po.OrderID, s.Name AS SupplierName, po.TotalAmount
FROM PurchaseOrder po
JOIN Bid b ON po.BidID = b.BidID
JOIN supplier s ON b.SupplierID = s.SupplierID
ORDER BY po.TotalAmount DESC
LIMIT 10;

-- Serial vs Parallel comparisons (on this node)
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT b.SupplierID, COUNT(*) AS orders_count
FROM Bid b
JOIN PurchaseOrder po ON b.BidID = po.BidID
GROUP BY b.SupplierID;

SET max_parallel_workers_per_gather = 4;
EXPLAIN ANALYZE
SELECT b.SupplierID, COUNT(*) AS orders_count
FROM Bid b
JOIN PurchaseOrder po ON b.BidID = po.BidID
GROUP BY b.SupplierID;


-- ---------------------------
-- 14) Final Checks: counts & simple queries to confirm distribution
-- ---------------------------

-- From OperationsDB, show bids with supplier names (via foreign table)
SELECT b.BidID, b.Amount, s.Name AS Supplier
FROM Bid b
LEFT JOIN supplier s ON b.SupplierID = s.SupplierID
ORDER BY b.BidID;

-- From ProcurementDB, show purchase requests
\c ProcurementDB
SELECT * FROM PurchaseRequest ORDER BY RequestID;

-- From OperationsDB, confirm payments/orders
\c OperationsDB
SELECT * FROM PurchaseOrder;
SELECT * FROM Payment;

-- ============================================================
-- End of E-Procurement Distributed Database Script
-- ============================================================
