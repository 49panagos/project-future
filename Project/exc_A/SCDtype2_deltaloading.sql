-- OLTP -> staging

USE [ChinookStaging]
GO

truncate table [ChinookStaging].[dbo].[Customers];

insert into Customers(Customerid, FirstName, LastName, Company, City, PostalCode, State, Country)
select Customerid, FirstName, LastName, Company, City, PostalCode, State, Country
from  [Chinook].[dbo].Customer;

-----------------------------------------------------------
truncate table [ChinookStaging].[dbo].[Sales];

insert into Sales ([InvoiceLine].InvoiceId, [InvoiceLine].TrackId, [Invoice].CustomerId, EmployeeId, InvoiceDate, UnitPrice)
select	[InvoiceLine].InvoiceId, [InvoiceLine].TrackId, [Invoice].CustomerId, EmployeeId, InvoiceDate, Chinook.[dbo].Track.UnitPrice
from Chinook.[dbo].[InvoiceLine]  
INNER JOIN Chinook.[dbo].[Invoice] ON Chinook.[dbo].InvoiceLine.InvoiceId = Chinook.[dbo].Invoice.InvoiceId
INNER JOIN Chinook.[dbo].Track ON Chinook.[dbo].InvoiceLine.TrackId = Chinook.[dbo].Track.TrackId
INNER JOIN Chinook.[dbo].[Customer] ON Chinook.[dbo].[Invoice].[CustomerId]=Chinook.[dbo].Customer.CustomerId
INNER JOIN Chinook.[dbo].[Employee] ON Chinook.[dbo].[Customer].[SupportRepId]=Chinook.[dbo].[Employee].[EmployeeId]
where InvoiceDate>='2013-12-23';
--------------------------------------------------------
 
--- staging ->DW
 
drop table if exists [ChinookStaging].[dbo].Staging_DimCustomer;

create table [ChinookStaging].[dbo].Staging_DimCustomer (
	CustomerKey INT IDENTITY(1,1) NOT NULL,
    CustomerID int not NULL,
	CustomerName VARCHAR(60) NOT NULL,
	CompanyName NVARCHAR(80) NULL,
    CustomerCity NVARCHAR(40) NULL,
    CustomerPostalCode NVARCHAR(10) NULL,
    CustomerState NVARCHAR(40) NULL,
	CustomerCountry NVARCHAR(40) NULL,
    RowIsCurrent INT DEFAULT 1 NOT NULL,
    RowStartDate DATE DEFAULT '2009-01-01' NOT NULL,
    RowEndDate DATE DEFAULT '9999-12-31' NOT NULL,
    RowChangeReason VARCHAR(200) NULL 
);

------------------------------
Insert into [ChinookStaging].[dbo].Staging_DimCustomer(CustomerID, CustomerName, CompanyName, 
CustomerCity, CustomerPostalCode, CustomerState, CustomerCountry)
   (Select Customerid, 
	[FirstName]+' '+[LastName], 
	Company, City, 
	case when [PostalCode] is null then 'n/a' else [PostalCode] end, 
	State, 
	Country
from [ChinookStaging].[dbo].[Customers]); 

 -------------------------------------------------


--drop the constraints 

declare @etldate date = '2013-12-23';


INSERT INTO [ChinookDW].[dbo].DimCustomer(
	CustomerID, CustomerName, CompanyName, 
	CustomerCity, CustomerPostalCode, CustomerState, 
	CustomerCountry,RowStartDate, RowChangeReason)
SELECT 
	CustomerID, CustomerName, CompanyName, CustomerCity, CustomerPostalCode, CustomerState, CustomerCountry, @etldate, ActionName
FROM
(
	MERGE [ChinookDW].[dbo].DimCustomer AS target
		USING [ChinookStaging].[dbo].Staging_DimCustomer as source
		ON target.[CustomerID] = source.[CustomerID]
	 WHEN MATCHED 	 AND 
	 source.CustomerCity <> target.CustomerCity  
	 AND target.[RowIsCurrent] = 1 
	 THEN UPDATE SET
		 target.RowIsCurrent = 0,
		 target.RowEndDate = dateadd(day, -1, @etldate ) ,
		 target.RowChangeReason = 'UPDATED NOT CURRENT'
	 WHEN NOT MATCHED THEN
	   INSERT  (
			CustomerID, CustomerName, CompanyName, CustomerCity, CustomerPostalCode, CustomerState, CustomerCountry, RowStartDate, RowChangeReason
	   )
	   VALUES( 
		   source.CustomerID,source.CustomerName,source.CompanyName, source.CustomerCity, source.CustomerPostalCode,source.CustomerState, source.CustomerCountry, CAST(@etldate AS Date), 'NEW RECORD'
	   )
	WHEN NOT MATCHED BY Source THEN
		UPDATE SET 
			Target.RowEndDate= dateadd(day, -1, @etldate )
			,target.RowIsCurrent = 0
			,Target.RowChangeReason  = 'SOFT DELETE'
	OUTPUT 
		  source.CustomerID,source.CustomerName,source.CompanyName, source.CustomerCity, 
		  source.CustomerPostalCode,source.CustomerState, source.CustomerCountry, $Action as ActionName   
) AS Mrg
WHERE Mrg.ActionName='UPDATE'
AND [CustomerID] IS NOT NULL;



------------------------------------------------
-- insert new facts ...

INSERT INTO [ChinookDW].[dbo].FactSales(
    InvoiceId, TrackKey, CustomerKey, EmployeeKey, InvoiceDateKey, UnitPrice)
SELECT s.InvoiceId,
    t.TrackKey,
    c.CustomerKey,
    e.EmployeeKey,
    CAST(FORMAT(s.InvoiceDate, 'yyyyMMdd') AS INT),
    s.UnitPrice
FROM 
	ChinookStaging.dbo.Sales AS s
	JOIN [ChinookDW].[dbo].[DimCustomer] AS c ON c.CustomerID = s.CustomerID and c.RowIsCurrent=1
	JOIN [ChinookDW].[dbo].[DimEmployee] AS e ON e.EmployeeID = s.EmployeeID and c.RowIsCurrent=1
	JOIN [ChinookDW].[dbo].[DimTrack] AS t ON t.TrackID = s.TrackID and c.RowIsCurrent=1
