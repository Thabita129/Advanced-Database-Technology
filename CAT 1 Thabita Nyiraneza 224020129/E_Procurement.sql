--Thabita NYIRANEZA
--Reg No: 224020129
--Advanced Database Technology

-- Drop existing tables if any (optional for clean setup)
DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Delivery CASCADE;
DROP TABLE IF EXISTS PurchaseOrder CASCADE;
DROP TABLE IF EXISTS Bid CASCADE;
DROP TABLE IF EXISTS PurchaseRequest CASCADE;
DROP TABLE IF EXISTS Supplier CASCADE;

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

-- QUERIES
-- -----------------------------

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

CREATE TRIGGER trg_update_supplier_rating
AFTER UPDATE ON Delivery
FOR EACH ROW
EXECUTE FUNCTION update_supplier_rating();


