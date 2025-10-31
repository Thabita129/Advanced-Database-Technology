--Thabita NYIRANEZA
--Reg No: 224020129
--Advanced Database Technology Final Exam

--I am going to split my E-Procurement database across two nodes (Branch A and Branch B). 
--Instead of one big database storing everything each node holds part of the data 
--but I can still query them as if they were one database.
-- Branch A(has Supplier and PurchaseRequest Tables)
-- Branch B (has Bid, PurchaseOrder, Payment and Delivery)
-----------------------------------------------------

--Branch A database

-- 1. Supplier Table
CREATE TABLE Supplier (
    SupplierID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Contact VARCHAR(50),
    Email VARCHAR(100) UNIQUE,
    Rating NUMERIC(3,2) CHECK (Rating >= 0 AND Rating <= 5)
);

-- 2. PurchaseRequest Table
CREATE TABLE PurchaseRequest (
    RequestID SERIAL PRIMARY KEY,
    Department VARCHAR(100) NOT NULL,
    RequestedBy VARCHAR(100) NOT NULL,
    DateRequested DATE NOT NULL,
    Status VARCHAR(20) CHECK (Status IN ('Pending', 'Approved', 'Rejected'))
);

-- Sample data
INSERT INTO Supplier (Name, Contact, Email, Rating)
VALUES
('ABC Supplies Ltd', '0788888888', 'abc@supplies.com', 4.5),
('QuickSource Co', '0799999999', 'quick@source.com', 4.2);

SELECT * FROM Supplier

INSERT INTO PurchaseRequest (Department, RequestedBy, DateRequested, Status)
VALUES
('IT', 'John Doe', '2025-10-10', 'Pending'),
('Finance', 'Mary Umutoni', '2025-10-12', 'Approved'),
('HR', 'Jacques Mugabo', '2025-10-14', 'Approved');

SELECT * FROM PurchaseRequest




