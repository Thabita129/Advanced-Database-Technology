ADVANCED DATABASE TECHNOLOGY EXAM

README FILE FOR E-Procurement Database Project



# E-Procurement Database Project 
# Step by Step Explanation of the tasks I have to implement with SQL Codes


# TASK A1: CREATE DATABASE LINK - BUILDING THE CONNECTION BRIDGE


First, we must establish a direct communication route between our two database servers. Consider this as constructing a safe bridge connecting two islands, Node_A and Node_B. The database link works as a dedicated road, allowing Node_A to travel to Node_B and retrieve data as needed. This connection is authenticated and secure, allowing only allowed access between databases.

# SQL CODES

-- Step 1: Create fragmented tables on both nodes
-- On Node_A:
CREATE TABLE PurchaseOrder_A (
    OrderID NUMBER PRIMARY KEY,
    BidID NUMBER,
    OrderDate DATE,
    Quantity NUMBER,
    TotalAmount NUMBER,
    Status VARCHAR2(20)
);

-- On Node_B:
CREATE TABLE PurchaseOrder_B (
    OrderID NUMBER PRIMARY KEY,
    BidID NUMBER,
    OrderDate DATE,
    Quantity NUMBER,
    TotalAmount NUMBER,
    Status VARCHAR2(20)
);

-- Step 2: Insert sample data (5 rows each, total 10)
-- On Node_A:
INSERT INTO PurchaseOrder_A VALUES (1, 101, DATE '2024-01-15', 100, 5000, 'COMPLETED');
INSERT INTO PurchaseOrder_A VALUES (3, 103, DATE '2024-01-17', 150, 7500, 'PENDING');
INSERT INTO PurchaseOrder_A VALUES (5, 105, DATE '2024-01-19', 200, 10000, 'COMPLETED');
INSERT INTO PurchaseOrder_A VALUES (7, 107, DATE '2024-01-21', 75, 3750, 'CANCELLED');
INSERT INTO PurchaseOrder_A VALUES (9, 109, DATE '2024-01-23', 120, 6000, 'COMPLETED');
COMMIT;

-- On Node_B:
INSERT INTO PurchaseOrder_B VALUES (2, 102, DATE '2024-01-16', 80, 4000, 'COMPLETED');
INSERT INTO PurchaseOrder_B VALUES (4, 104, DATE '2024-01-18', 180, 9000, 'PENDING');
INSERT INTO PurchaseOrder_B VALUES (6, 106, DATE '2024-01-20', 90, 4500, 'COMPLETED');
INSERT INTO PurchaseOrder_B VALUES (8, 108, DATE '2024-01-22', 160, 8000, 'COMPLETED');
INSERT INTO PurchaseOrder_B VALUES (10, 110, DATE '2024-01-24', 110, 5500, 'PENDING');
COMMIT;

-- Step 3: Create database link (on Node_A)
CREATE DATABASE LINK proj_link 
CONNECT TO your_username IDENTIFIED BY your_password
USING 'Node_B_Service_Name';

-- Step 4: Create unified view (on Node_A)
CREATE VIEW PurchaseOrder_ALL AS
SELECT * FROM PurchaseOrder_A
UNION ALL
SELECT * FROM PurchaseOrder_B@proj_link;

-- Step 5: Validation queries
-- Count validation
SELECT 'Fragment_A' as source, COUNT(*) as row_count FROM PurchaseOrder_A
UNION ALL
SELECT 'Fragment_B' as source, COUNT(*) as row_count FROM PurchaseOrder_B@proj_link
UNION ALL
SELECT 'Combined_View' as source, COUNT(*) as row_count FROM PurchaseOrder_ALL;

-- Checksum validation
SELECT 'Fragment_A' as source, SUM(MOD(OrderID, 97)) as checksum FROM PurchaseOrder_A
UNION ALL
SELECT 'Fragment_B' as source, SUM(MOD(OrderID, 97)) as checksum FROM PurchaseOrder_B@proj_link
UNION ALL
SELECT 'Combined_View' as source, SUM(MOD(OrderID, 97)) as checksum FROM PurchaseOrder_ALL;

-------------------------------------------------------------

TASK A2 Explanation 

Database Link & Cross-Node Join


1. Building the Connection

First, I need to establish a direct communication link between my two database servers (Nodes_A and B). It lets Node_A to immediately access and retrieve data from Node_B as needed. I set up this connection once and name it.

2. Test Remote Access or Testing the Link

Once the connection is established, I should test it to ensure that everything functions properly. I'll accomplish this by performing a simple query that instructs Node_B to submit some sample supplier data across the new connection. This verification phase guarantees that the bridge between the two databases works properly before I use it for more crucial operations.

3. Perform Database Link & Cross-Node Join or Combining Data from Both Sources
I've used a "distributed join" to combine information from both databases into a single result. Specifically, I combine purchase order data from your local database (Node_A) with bid information from the remote database (Node_B) to display entire order details and matching supplier bids in a single unified view.

--SQL CODES

-- Step 1: Remote data access (from Node_A)
SELECT * FROM (
    SELECT * FROM Supplier@proj_link 
    ORDER BY SupplierID
) WHERE ROWNUM <= 5;

-- Step 2: Distributed join query
SELECT po.OrderID, po.TotalAmount, b.BidID, b.Amount, b.Decision
FROM PurchaseOrder_A po
JOIN Bid@proj_link b ON po.BidID = b.BidID
WHERE po.TotalAmount BETWEEN 4000 AND 8000
AND b.Decision = 'ACCEPTED'
ORDER BY po.OrderID;

----------------------------------------------------------------
# TASK A3: PARALLEL VS SERIAL AGGREGATION


We're comparing two alternative data processing methods: one worker doing all of the work (serial) and numerous workers dividing the work (parallel). Even with minimal datasets, we can examine how the database engine handles various approaches.

-- Serial aggregation (single worker)
SELECT Status, COUNT(*) as order_count, SUM(TotalAmount) as total_value
FROM PurchaseOrder_ALL
GROUP BY Status
ORDER BY Status;

-- Parallel aggregation (multiple workers)
SELECT /*+ PARALLEL(PurchaseOrder_A, 8) PARALLEL(PurchaseOrder_B, 8) */
       Status, COUNT(*) as order_count, SUM(TotalAmount) as total_value
FROM PurchaseOrder_ALL
GROUP BY Status
ORDER BY Status;

-- Check execution plans to see the difference
EXPLAIN PLAN FOR
SELECT Status, COUNT(*) as order_count, SUM(TotalAmount) as total_value
FROM PurchaseOrder_ALL
GROUP BY Status;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-------------------------------------------------------------

# TASK A4: TWO-PHASE COMMIT & RECOVERY


We are developing a safety method for transactions involving various databases. This ensures that when we update data on both servers, either both changes succeed or fail completely, never leaving one updated while the other remains unaltered.

-- Safe distributed transaction
DECLARE
BEGIN
    -- Insert on local node
    INSERT INTO PurchaseOrder_A VALUES (11, 111, SYSDATE, 130, 6500, 'PENDING');
    
    -- Insert on remote node
    INSERT INTO PurchaseOrder_B@proj_link VALUES (12, 112, SYSDATE, 140, 7000, 'PENDING');
    
    COMMIT; -- Both inserts commit together or not at all
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK; -- If any error, both inserts are rolled back
END;
/

-- Check for pending transactions if something goes wrong
SELECT * FROM DBA_2PC_PENDING;

-- Force resolution if transactions get stuck
-- COMMIT FORCE 'transaction_id';
-- OR
-- ROLLBACK FORCE 'transaction_id';

---------------------------------------------------------------

# TASK A5: DISTRIBUTED LOCK CONFLICT & DIAGNOSIS


We're mimicking what occurs when two people attempt to update the same data simultaneously from different locations. This demonstrates how the database avoids data corruption by locking records, as well as how to discover and resolve such conflicts.

-- Session 1 (Node_A - locks the record):
UPDATE PurchaseOrder_A SET Status = 'PROCESSING' WHERE OrderID = 1;
-- DON'T COMMIT YET - keep the lock active

-- Session 2 (Node_B - tries to update same record):
UPDATE PurchaseOrder_A@proj_link SET Status = 'COMPLETED' WHERE OrderID = 1;
-- This will wait until Session 1 releases the lock

-- Diagnosis: Check who's blocking whom
SELECT * FROM DBA_BLOCKERS;
SELECT * FROM DBA_WAITERS;

-- Resolution: Session 1 commits to release lock
COMMIT;

--------------------------------------------------------------

# TASK B6: DECLARATIVE RULES HARDENING


We are integrating business rules directly into the database schema to prevent invalid data from being entered. This is similar to having a bouncer at the door who verifies IDs; only valid data is allowed in.

-- Add data validation rules to tables
ALTER TABLE PurchaseOrder_A 
ADD CONSTRAINT chk_po_quantity CHECK (Quantity > 0),
ADD CONSTRAINT chk_po_amount CHECK (TotalAmount >= 0),
ADD CONSTRAINT chk_po_status CHECK (Status IN ('PENDING','PROCESSING','COMPLETED','CANCELLED'));

-- Test valid data (should work)
BEGIN
    INSERT INTO PurchaseOrder_A VALUES (15, 115, SYSDATE, 100, 5000, 'PENDING');
    COMMIT;
END;
/

-- Test invalid data (should fail with clear error messages)
BEGIN
    INSERT INTO PurchaseOrder_A VALUES (16, 116, SYSDATE, -50, 5000, 'PENDING');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
        ROLLBACK;
END;
/

---------------------------------------------------------------

# TASK B7: E-C-A TRIGGER FOR DENORMALIZED TOTALS

We're developing an automated monitoring system that detects changes in our data and automatically updates associated totals. This ensures that summary data is constantly in line with detailed records.

-- Create audit table to track changes
CREATE TABLE PurchaseOrder_AUDIT (
    audit_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bef_total NUMBER,
    aft_total NUMBER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operation_type VARCHAR2(10)
);

-- Create trigger that automatically updates and audits
CREATE OR REPLACE TRIGGER trg_po_totals_audit
AFTER INSERT OR UPDATE OR DELETE ON PurchaseOrder_A
DECLARE
    v_before_total NUMBER;
    v_after_total NUMBER;
BEGIN
    -- Calculate totals before and after changes
    SELECT NVL(SUM(TotalAmount), 0) INTO v_before_total FROM PurchaseOrder_A;
    SELECT NVL(SUM(TotalAmount), 0) INTO v_after_total FROM PurchaseOrder_A;
    
    -- Record the change
    INSERT INTO PurchaseOrder_AUDIT (bef_total, aft_total, operation_type)
    VALUES (v_before_total, v_after_total, 'UPDATE');
END;
/

------------------------------------------------------------------

# TASK B8: RECURSIVE HIERARCHY ROLL-UP


We are creating organizational charts and calculating totals that will be rolled up via management tiers. This allows us to answer queries such as, "How much did each department and its sub-departments spend?"

-- Create department hierarchy table
CREATE TABLE Department_Hierarchy (
    parent_id VARCHAR2(10),
    child_id VARCHAR2(10) PRIMARY KEY,
    dept_name VARCHAR2(50)
);

-- Build organizational structure
INSERT INTO Department_Hierarchy VALUES (NULL, 'CORP', 'Corporate Headquarters');
INSERT INTO Department_Hierarchy VALUES ('CORP', 'FIN', 'Finance Department');
INSERT INTO Department_Hierarchy VALUES ('CORP', 'OPS', 'Operations Department');

-- Recursive query to traverse hierarchy
WITH DeptHierarchy (child_id, root_id, depth, path) AS (
    SELECT child_id, child_id, 0, dept_name
    FROM Department_Hierarchy 
    WHERE parent_id IS NULL
    UNION ALL
    SELECT dh.child_id, cte.root_id, cte.depth + 1, cte.path || ' -> ' || dh.dept_name
    FROM Department_Hierarchy dh
    JOIN DeptHierarchy cte ON dh.parent_id = cte.child_id
)
SELECT child_id, root_id, depth, path
FROM DeptHierarchy
ORDER BY root_id, depth;

----------------------------------------------------------------

# TASK B9: MINI-KNOWLEDGE BASE WITH TRANSITIVE INFERENCE


We're developing a smart system that can make logical inferences depending on the rules we establish. This enables the database to "reason" about relationships and apply labels or limits depending on predefined business rules.

-- Create knowledge base using subject-predicate-object triples
CREATE TABLE Procurement_Triple (
    subject VARCHAR2(64),
    predicate VARCHAR2(64),
    object VARCHAR2(64)
);

-- Define business rules and relationships
INSERT INTO Procurement_Triple VALUES ('Electronics', 'requires_approval', 'Director');
INSERT INTO Procurement_Triple VALUES ('Director', 'reports_to', 'CEO');

-- Recursive inference engine
WITH ApprovalChain (item, approver, level) AS (
    SELECT subject, object, 1
    FROM Procurement_Triple
    WHERE predicate = 'requires_approval'
    UNION ALL
    SELECT ac.item, pt.object, ac.level + 1
    FROM ApprovalChain ac
    JOIN Procurement_Triple pt ON ac.approver = pt.subject
    WHERE pt.predicate = 'reports_to'
)
SELECT * FROM ApprovalChain;

---------------------------------------------------------------

# TASK B10: BUSINESS LIMIT ALERT SYSTEM


We are developing an automatic compliance checker to prevent users from violating corporate regulations. This system continually monitors data changes and prevents any transactions that might violate the established business restrictions.

-- Define business rules table
CREATE TABLE BUSINESS_LIMITS (
    rule_key VARCHAR2(64) PRIMARY KEY,
    threshold NUMBER,
    active CHAR(1) CHECK (active IN ('Y','N'))
);

INSERT INTO BUSINESS_LIMITS VALUES ('MAX_SINGLE_ORDER', 8000, 'Y');
COMMIT;

-- Create rule validation function
CREATE OR REPLACE FUNCTION fn_should_alert(p_order_amount IN NUMBER) RETURN NUMBER
IS
    v_threshold NUMBER;
BEGIN
    SELECT threshold INTO v_threshold 
    FROM BUSINESS_LIMITS 
    WHERE rule_key = 'MAX_SINGLE_ORDER' AND active = 'Y';
    
    RETURN CASE WHEN p_order_amount > v_threshold THEN 1 ELSE 0 END;
END;
/

-- Create enforcement trigger
CREATE OR REPLACE TRIGGER trg_order_amount_check
BEFORE INSERT OR UPDATE ON PurchaseOrder_A
FOR EACH ROW
BEGIN
    IF fn_should_alert(:NEW.TotalAmount) = 1 THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Order amount exceeds business limit of 8000');
    END IF;
END;
/

-- Test the system
BEGIN
    INSERT INTO PurchaseOrder_A VALUES (20, 120, SYSDATE, 100, 7500, 'PENDING'); -- Should work
    INSERT INTO PurchaseOrder_A VALUES (21, 121, SYSDATE, 200, 9000, 'PENDING'); -- Should fail
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
        ROLLBACK;
END;
/

SUMMARY

This comprehensive E-Procurement database project required building a distributed system that horizontally fragmented purchase order data across two database nodes, established secure cross-database communication links, and implemented advanced features such as parallel processing, distributed transaction safety with two-phase commit protocols. Automated business rule enforcement via constraints and triggers, hierarchical data roll-up capabilities using recursive queries, a logical inference engine for automated decision-making, and a proactive alert system that prevents policy violations - all while adhering to a strict 10-row data budget to demonstrate efficient resource management and data integrity across the entire distributed architecture.