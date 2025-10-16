--Thabita NYIRANEZA
--Reg No: 224020129
--Advanced Database Technology

--E-Procurement and Supplier Management System

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

-- 3. Bid Table
CREATE TABLE Bid (
    BidID SERIAL PRIMARY KEY,
    SupplierID INT REFERENCES Supplier(SupplierID) ON DELETE CASCADE,
    RequestID INT REFERENCES PurchaseRequest(RequestID) ON DELETE CASCADE,
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    DeliveryDays INT CHECK (DeliveryDays > 0),
    Decision VARCHAR(20) CHECK (Decision IN ('Pending', 'Approved', 'Rejected'))
);

-- 4. PurchaseOrder Table
CREATE TABLE PurchaseOrder (
    OrderID SERIAL PRIMARY KEY,
    BidID INT UNIQUE REFERENCES Bid(BidID) ON DELETE CASCADE,
    OrderDate DATE NOT NULL,
    Quantity INT CHECK (Quantity > 0),
    TotalAmount NUMERIC(12,2) CHECK (TotalAmount > 0)
);

-- 5. Delivery Table
CREATE TABLE Delivery (
    DeliveryID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE REFERENCES PurchaseOrder(OrderID) ON DELETE CASCADE,
    DeliveryDate DATE,
    Status VARCHAR(20) CHECK (Status IN ('Pending', 'Delivered', 'Rejected')),
    ReceivedBy VARCHAR(100)
);

-- 6. Payment Table
CREATE TABLE Payment (
    PaymentID SERIAL PRIMARY KEY,
    OrderID INT UNIQUE REFERENCES PurchaseOrder(OrderID) ON DELETE CASCADE,
    Amount NUMERIC(12,2) CHECK (Amount > 0),
    PaymentDate DATE,
    Method VARCHAR(30) CHECK (Method IN ('Cash', 'BankTransfer', 'Cheque'))
);

select * from Payment --To see how my table look like


-- INSERT SAMPLE DATA

INSERT INTO Supplier (Name, Contact, Email, Rating)
VALUES
('ABC Supplies Ltd', '0788888888', 'abc@supplies.com', 4.5),
('QuickSource Co', '0799999999', 'quick@source.com', 4.2),
('RwandaTrade', '0722222222', 'info@rwandatrade.com', 3.8);

INSERT INTO PurchaseRequest (Department, RequestedBy, DateRequested, Status)
VALUES
('IT', 'John Doe', '2025-10-01', 'Pending'),
('Finance', 'Mary Umutoni', '2025-10-02', 'Approved'),
('HR', 'Alice Iradukunda', '2025-10-03', 'Approved'),
('Procurement', 'David Niyonzima', '2025-10-04', 'Pending'),
('Operations', 'Samuel Habimana', '2025-10-05', 'Approved');

select * from PurchaseRequest  --To see how my table look like

    INSERT INTO Bid (BidID, SupplierID, RequestID, Amount, DeliveryDays, Decision) VALUES
(1, 1, 1, 5000.00, 15, 'Approved'),
(2, 2, 2, 7500.00, 10, 'Approved'),
(3, 3, 3, 12000.00, 20, 'Approved'),
(4, 1, 4, 4500.00, 12, 'Approved'),
(5, 2, 5, 9000.00, 8, 'Approved');

-- Verify the inserted data
SELECT * FROM Bid;

INSERT INTO PurchaseOrder (BidID, OrderDate, Quantity, TotalAmount) VALUES
(1, '2024-01-15', 100, 5000.00),
(2, '2024-01-18', 50, 7500.00),
(3, '2024-01-20', 200, 12000.00),
(4, '2024-01-22', 75, 4500.00),
(5, '2024-01-25', 150, 9000.00);

-- Verify the inserted data
SELECT * FROM PurchaseOrder;


-- QUERIES

-- 1. Retrieve all approved bids with supplier info
SELECT 
    B.BidID, B.Amount, B.DeliveryDays, 
    S.Name AS SupplierName, S.Email, S.Rating
FROM Bid B
JOIN Supplier S ON B.SupplierID = S.SupplierID
WHERE B.Decision = 'Approved';

-- 2. Update bid status after purchase order creation
UPDATE Bid
SET Decision = 'Approved'
WHERE BidID IN (SELECT BidID FROM PurchaseOrder);

-- 3. Identify suppliers with fastest delivery record
SELECT 
    S.SupplierID,
    S.Name,
    AVG(B.DeliveryDays) AS AvgDeliveryTime
FROM Supplier S
JOIN Bid B ON S.SupplierID = B.SupplierID
JOIN PurchaseOrder P ON P.BidID = B.BidID
JOIN Delivery D ON D.OrderID = P.OrderID
WHERE D.Status = 'Delivered'
GROUP BY S.SupplierID, S.Name
ORDER BY AvgDeliveryTime ASC
LIMIT 1;

-- 4. View: total procurement cost per supplier
CREATE OR REPLACE VIEW SupplierProcurementSummary AS
SELECT 
    S.SupplierID,
    S.Name AS SupplierName,
    SUM(Po.TotalAmount) AS TotalProcurementCost
FROM Supplier S
JOIN Bid B ON S.SupplierID = B.SupplierID
JOIN PurchaseOrder Po ON Po.BidID = B.BidID
GROUP BY S.SupplierID, S.Name;

-- 5. Trigger: update supplier rating after successful delivery
CREATE OR REPLACE FUNCTION update_supplier_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Status = 'Delivered' THEN
        UPDATE Supplier
        SET Rating = LEAST(Rating + 0.1, 5.0)
        WHERE SupplierID = (
            SELECT S.SupplierID
            FROM Supplier S
            JOIN Bid B ON S.SupplierID = B.SupplierID
            JOIN PurchaseOrder P ON P.BidID = B.BidID
            WHERE P.OrderID = NEW.OrderID
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DELETE FROM PurchaseOrder 
WHERE OrderId = '3';



