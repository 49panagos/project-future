USE master
GO
if exists (select * from sysdatabases where name='ChinookStaging')
		alter database ChinookStaging set single_user with rollback immediate
		drop database ChinookStaging
go

CREATE DATABASE ChinookStaging
GO

USE ChinookStaging
GO

DROP TABLE IF EXISTS ChinookStaging.dbo.Sales
DROP TABLE IF EXISTS ChinookStaging.dbo.Customers
DROP TABLE IF EXISTS ChinookStaging.dbo.Employees
DROP TABLE IF EXISTS ChinookStaging.dbo.Tracks

--1. get data FROM Employee
--  EmployeeID,   FirstName,  LastName, JobTitle 

SELECT 
	Employeeid, 
	FirstName, 
	LastName, 
	Title as JobTitle
INTO ChinookStaging.dbo.Employees
FROM Chinook.[dbo].[Employee]

--2 get data FROM Customer
-- CustomerID, FirstName, LastName, Company, City, PostalCode, State, Country

SELECT  Customerid, FirstName, LastName, Company, City, PostalCode, State, Country
INTO ChinookStaging.dbo.Customers
FROM Chinook.[dbo].[Customer]

--3  get FROM Track
 -- TrackID, TrackName, AlbumName, ArtistName, PlaylistName, GenreName, MediaTypeName, UnitPrice


-- 3 get FROM Track
-- TrackID, TrackName, AlbumName, ArtistName, PlaylistName, GenreName, MediaTypeName

SELECT 
    [Track].TrackId, 
    [Track].Name as Track, 
    ISNULL([Album].[Title], 'N/A') as Album, 
    ISNULL([Artist].Name, 'N/A') as Artist, 
    ISNULL([Genre].Name, 'N/A') as Genre, 
    ISNULL([MediaType].Name, 'N/A') as MediaType
INTO ChinookStaging.dbo.Tracks
FROM Chinook.[dbo].[Track]
LEFT JOIN Chinook.[dbo].[Album]
    ON Chinook.[dbo].Track.AlbumId = Chinook.[dbo].Album.AlbumId
LEFT JOIN Chinook.[dbo].[Artist]
    ON Chinook.[dbo].Track.AlbumId = Chinook.[dbo].Artist.ArtistId
LEFT JOIN Chinook.[dbo].Genre
    ON Chinook.[dbo].Track.GenreId = Chinook.[dbo].Genre.GenreId
LEFT JOIN Chinook.[dbo].MediaType
    ON Chinook.[dbo].Track.MediaTypeId = Chinook.[dbo].MediaType.MediaTypeId



--4  get FROM InvoiceLine
-- InvoiceId, TrackId, CustomerId, EmployeeId, InvoiceDate, BillingCountry, UnitPrice

SELECT 
	[InvoiceLine].InvoiceId, 
	[InvoiceLine].TrackId, 
	[Invoice].CustomerId, 
	EmployeeId, 
	InvoiceDate,  
	[InvoiceLine].UnitPrice
INTO ChinookStaging.dbo.Sales
FROM Chinook.[dbo].[InvoiceLine] 
INNER JOIN Chinook.[dbo].[Invoice] ON Chinook.[dbo].InvoiceLine.InvoiceId = Chinook.[dbo].Invoice.InvoiceId
INNER JOIN Chinook.[dbo].Track ON Chinook.[dbo].InvoiceLine.TrackId = Chinook.[dbo].Track.TrackId
INNER JOIN Chinook.[dbo].[Customer] ON Chinook.[dbo].[Invoice].[CustomerId]=Chinook.[dbo].Customer.CustomerId
INNER JOIN Chinook.[dbo].[Employee] ON Chinook.[dbo].[Customer].[SupportRepId]=Chinook.[dbo].[Employee].[EmployeeId]

--5 date dimension


SELECT MIN(InvoiceDate) minDate, MAX(InvoiceDate) maxDate FROM Sales
