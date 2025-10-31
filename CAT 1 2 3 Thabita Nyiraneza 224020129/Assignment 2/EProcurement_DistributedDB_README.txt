E-Procurement and Supply Management – Distributed Database Project


This project demonstrates distributed database techniques applied to an E-Procurement and Supply Management System. 
Each task focuses on optimizing performance, reliability, and data consistency across multiple database nodes.


1. Distributed Schema Design and Fragmentation

- Split the main E-Procurement database into two nodes: BranchDB_A (Procurement) and BranchDB_B (Suppliers & Inventory).
- Applied horizontal fragmentation on the ORDERS table and vertical fragmentation on the SUPPLIER table.
- Submitted ER diagrams and SQL scripts that create both schemas.


2. Database Links and Distributed Joins

- Created a database link between BranchDB_A and BranchDB_B.
- Demonstrated remote SELECT queries and distributed joins between ORDERS and SUPPLIERS tables.
- Verified successful communication and query results between the two schemas.


3. Parallel Query Execution

- Enabled parallel query processing on the TRANSACTIONS table.
- Used the PARALLEL hint to improve performance.
- Compared serial vs parallel execution time using EXPLAIN PLAN.


4. Two-Phase Commit Simulation

- Developed a PL/SQL block to insert records on both nodes and commit as one atomic transaction.
- Verified atomicity with DBA_2PC_PENDING views.
- Ensured no partial commits occurred during distributed execution.


5. Distributed Rollback and Recovery

- Simulated a network failure during a distributed transaction.
- Identified unresolved transactions and resolved them using ROLLBACK FORCE.
- Documented recovery steps and screenshots.


6. Distributed Concurrency Control

- Demonstrated a lock conflict scenario where two sessions updated the same order record from different nodes.
- Monitored locks using DBA_LOCKS.
- Explained how Oracle handled concurrent access and locking.


7. Parallel Data Loading / ETL Simulation

- Performed bulk data aggregation for procurement reports using PARALLEL DML.
- Compared execution times before and after enabling parallelism.
- Documented performance improvement.


8. Three-Tier Client–Server Architecture

- Designed a three-tier architecture: 
  Presentation (Web App), Application (API Layer), and Database (Distributed Nodes).
- Illustrated data flow and use of database links for supplier and order data synchronization.


9. Distributed Query Optimization

- Analyzed a distributed join query between PURCHASES and SUPPLIERS.
- Used DBMS_XPLAN.DISPLAY to study optimizer decisions and data movement minimization strategies.


10. Performance Benchmark and Report

- Executed a complex procurement query in three modes: centralized, parallel, and distributed.
- Collected execution time and I/O statistics using AUTOTRACE.
- Provided a half-page analysis on scalability and system efficiency.


