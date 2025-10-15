E-Procurement and Supplier Management System


Project Overview

The E-Procurement and Supplier Management System is a complete database solution that simplifies and automates the procurement process for enterprises. 
This system tracks supplier performance and provides transparency throughout the procurement process, from initial buy requests to final payments.

System Objectives

- Transparent Purchasing: Track all procurement activities from request to payment
- Supplier Performance Monitoring: Evaluate and rate suppliers based on delivery performance
- Efficient Bid Management: Streamline the bidding and supplier selection process
- Automated Workflow: Automate key processes like status updates and rating calculations

Database Schema


Tables Structure:

1. SUPPLIER TABLE
   - SupplierID (PK) - Unique identifier for each supplier
   - Name - Supplier company name
   - Contact - Contact person information
   - Email - Contact email address
   - Rating - Performance rating (0-5 scale)

2. PURCHASEREQUEST TABLE
   - RequestID (PK) - Unique request identifier
   - Department - Requesting department name
   - RequestedBy - Person who made the request
   - DateRequested - Request creation date
   - Status - Current status of the request

3. BID TABLE
   - BidID (Primary Key) - Unique bid identifier
   - SupplierID (Foreign Key) - References Supplier table
   - RequestID (Foreign Key) - References PurchaseRequest table
   - Amount - Bid amount
   - DeliveryDays - Proposed delivery timeline
   - Decision - Bid status (Approved/Rejected/Pending)

4. PURCHASEORDER TABLE
   - OrderID (Primary Key) - Unique order identifier
   - BidID (Foreign Key) - References Bid table
   - OrderDate - PO creation date
   - Quantity - Ordered quantity
   - TotalAmount - Total order value

5. DELIVERY TABLE
   - DeliveryID (Primary Key) - Unique delivery identifier
   - OrderID (Foreign Key) - References PurchaseOrder table
   - DeliveryDate - Actual delivery date
   - Status - Delivery status
   - ReceivedBy - Person who received the delivery

6. PAYMENT TABLE
   - PaymentID (Primary Key) - Unique payment identifier
   - OrderID (Foreign Key) - References PurchaseOrder table
   - Amount - Payment amount
   - PaymentDate - Date of payment
   - Method - Payment method used

Database Relationships

- Supplier → Bid (1:N) - One supplier can submit multiple bids
- PurchaseRequest → Bid (1:N) - One request can receive multiple bids
- Bid → PurchaseOrder (1:1) - One bid leads to one purchase order
- PurchaseOrder → Delivery (1:1) - One order has one delivery
- PurchaseOrder → Payment (1:1) - One order has one payment

Implementation Tasks


1. Create all tables with FK and CHECK constraints
2. Apply CASCADE DELETE between PurchaseOrder → Payment
3. Insert 3 suppliers and 5 purchase requests
4. Retrieve all approved bids with supplier information
5. Update bid status after purchase order creation
6. Identify suppliers with fastest delivery record
7. Create a view summarizing total procurement cost per supplier
8. Implement a trigger updating supplier rating after each successful delivery

Key Features


Query Capabilities:
- Approved Bids Report: View all approved bids with complete supplier details
- Supplier Performance: Track delivery performance and ratings
- Cost Analysis: Summarize procurement costs by supplier
- Status Tracking: Monitor request, bid, and delivery statuses

Automation Features:
- Automatic Rating Updates: Supplier ratings adjust based on delivery performance
- Status Propagation: Bid status updates automatically when purchase orders are created
- Cascade Operations: Automatic cleanup of related records with cascade delete

Reporting Views:
- Supplier Performance View: Comprehensive supplier rating and delivery analysis
- Procurement Cost View: Total spending per supplier for budgeting and analysis

Usage Examples


Monitoring Approved Bids:
SELECT * FROM approved_bids_with_suppliers;

Supplier Performance Analysis:
SELECT * FROM supplier_performance_view;

Procurement Cost Summary:
SELECT * FROM procurement_cost_per_supplier;

Data Integrity Features

- Foreign Key Constraints: Maintain referential integrity
- CHECK Constraints: Validate data inputs (e.g., rating between 0-5)
- Cascade Operations: Automatic deletion of related records
- Trigger-based Updates: Real-time rating and status updates

Business Benefits

- Increased Transparency: Full visibility throughout the procurement process
- Improved Decision Making: Data-driven supplier selection.
- Improved efficiency: Automated workflows minimize manual effort.
- Performance Tracking: Objective Supplier Evaluation Metrics
- Cost Control: Comprehensive expenditure analysis and reporting.
