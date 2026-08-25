DROP DATABASE IF EXISTS ECommerceDB;
CREATE DATABASE ECommerceDB;
USE ECommerceDB;

CREATE TABLE Customer (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    Phone VARCHAR(15) UNIQUE
);

CREATE TABLE Address (
    AddressID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    HouseNo VARCHAR(50) NOT NULL,
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50) NOT NULL,
    Pincode VARCHAR(10) NOT NULL,
    FOREIGN KEY (CustomerID)
        REFERENCES Customer(CustomerID)
        ON DELETE CASCADE
);

CREATE TABLE Seller (
    SellerID INT PRIMARY KEY,
    SellerName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Category (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Product (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    CategoryID INT NOT NULL,
    SellerID INT,
    FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID),
    FOREIGN KEY (SellerID)
        REFERENCES Seller(SellerID)
        ON DELETE SET NULL
);

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    FOREIGN KEY (CustomerID)
        REFERENCES Customer(CustomerID)
        ON DELETE CASCADE
);

CREATE TABLE OrderItem (
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
        ON DELETE CASCADE,
    FOREIGN KEY (ProductID)
        REFERENCES Product(ProductID)
);

CREATE TABLE Payment (
    PaymentID INT PRIMARY KEY,
    OrderID INT NOT NULL UNIQUE,
    PaymentMethod VARCHAR(30) NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
        ON DELETE CASCADE
);

CREATE TABLE Delivery (
    DeliveryID INT PRIMARY KEY,
    OrderID INT NOT NULL UNIQUE,
    AddressID INT,
    DeliveryStatus VARCHAR(30) NOT NULL,
    FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
        ON DELETE CASCADE,
    FOREIGN KEY (AddressID)
        REFERENCES Address(AddressID)
        ON DELETE SET NULL
);

INSERT INTO Customer
VALUES
(1, 'Gaurav Aryan', 'gaurav.aryan@gmail.com', '71255748647'),
(2, 'Prince Arya', 'princearya@gmail.com', '9876593211');

INSERT INTO Address
VALUES
(101, 1, 'House 12', 'Delhi', 'Delhi', '110001'),
(102, 2, 'House 45', 'Chandigarh', 'Punjab', '160001');

INSERT INTO Seller
VALUES
(201, 'Tech World', 'techworld@gmail.com'),
(202, 'Smart Store', 'smartstore@gmail.com');

INSERT INTO Category
VALUES
(301, 'Electronics'),
(302, 'Mobiles'),
(303, 'Laptops');

INSERT INTO Product
VALUES
(401, 'iPhone 15', 69999.00, 302, 201),
(402, 'Samsung Galaxy S24', 64999.00, 302, 202);

INSERT INTO Orders
VALUES
(501, 1, '2026-08-20'),
(502, 2, '2026-08-21');

INSERT INTO OrderItem
VALUES
(501, 401, 1, 69999.00),
(502, 402, 1, 55999.00);

INSERT INTO Payment
VALUES
(601, 501, 'UPI', 125998.00),
(602, 502, 'Credit Card', 129998.00);

INSERT INTO Delivery
VALUES
(701, 501, 101, 'Delivered'),
(702, 502, 102, 'Shipped');

SELECT * FROM Customer;
SELECT * FROM Address;
SELECT * FROM Seller;
SELECT * FROM Category;
SELECT * FROM Product;
SELECT * FROM Orders;
SELECT * FROM OrderItem;
SELECT * FROM Payment;
SELECT * FROM Delivery;