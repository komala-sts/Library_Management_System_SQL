--ADB: TASK 1.1
--Step1: Created Database named 'SalfordCityLibrary'
USE master ;  
GO  
DROP DATABASE IF EXISTS SalfordCityLibrary;
GO  
CREATE DATABASE SalfordCityLibrary;
GO  
USE SalfordCityLibrary;
GO

CREATE SCHEMA Library;
GO 
CREATE TABLE Library.Members
(
MemberID INT IDENTITY(1000,1) PRIMARY KEY NOT NULL,
Username NVARCHAR(40) UNIQUE NOT NULL,
PwdHash BINARY(64) NOT NULL,
Salt UNIQUEIDENTIFIER,
FirstName NVARCHAR(40) NOT NULL,
LastName NVARCHAR(40) NOT NULL,
DOB Date NOT NULL,
Email nvarchar(100) UNIQUE NOT NULL CHECK (Email LIKE '%_@_%._%'),
Telephone nvarchar(20) NOT NULL,
AddressID int NOT NULL,
Membership_StartDT Datetime Not Null,
Membership_EndDt Datetime NULL,
Total_outstanding money Default 0
);
GO 

CREATE TABLE Library.Addresses (
AddressID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
Address1 nvarchar(50) NOT NULL,
Address2 nvarchar(50) NULL,
City nvarchar(50) NOT NULL,
Postcode nvarchar(10) NOT NULL);
GO
ALTER TABLE Library.Members
ADD FOREIGN KEY (AddressID) REFERENCES Library.Addresses (AddressID);
GO

CREATE TABLE Library.Items (
ItemID int IDENTITY(100,1) NOT NULL PRIMARY KEY,
ItemTitle nvarchar(100) UNIQUE NOT NULL,
ItemType nvarchar(15) NOT NULL Default 'Book',
Author nvarchar(50) NOT NULL,
YOP nvarchar(4) NOT NULL,
ISBN nvarchar(20) NOT NULL,
AddedDt Datetime NOT NULL,
CurrentStatus nvarchar(10) NOT NULL Default 'Available',
RemovedDT Datetime NULL
);
GO

CREATE TABLE Library.Loans (
LoanID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
ItemID int NOT NULL FOREIGN KEY (ItemID) REFERENCES Library.Items(ItemID),
LoanStartDT Datetime NOT NULL,
LoanPeriod int NOT NULL DEFAULT 7,
LoanEndDT Datetime NOT NULL,
ReturnDT Datetime Null,
FineAmt money Default 0,
RepaidAmt money Default 0);
GO

CREATE TABLE Library.MemberLoans (
LoanID int NOT NULL FOREIGN KEY (LoanID) REFERENCES Library.Loans(LoanID),
MemberID INT NOT NULL FOREIGN KEY (MemberID ) REFERENCES Library.Members(MemberID),
PRIMARY KEY (LoanID, MemberID));
GO

CREATE TABLE Library.Repayments(
RepaymentID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
LoanID int NOT NULL FOREIGN KEY (LoanID) REFERENCES Library.Loans(LoanID),
PaymentDT DateTime NOT NULL,
Amount Money NOT NULL,
PaymentType nvarchar(4) NOT NULL Default 'Cash' );
GO
--MembersArchive for storing Deleted Members data (except Password)
CREATE TABLE Library.MembersArchive
(
MemberID INT  PRIMARY KEY NOT NULL,
Username NVARCHAR(40) NOT NULL,
FirstName NVARCHAR(40) NOT NULL,
LastName NVARCHAR(40) NOT NULL,
DOB Date NOT NULL,
Email nvarchar(100) NOT NULL CHECK (Email LIKE '%_@_%._%'),
Telephone nvarchar(20) NOT NULL,
AddressID int NOT NULL,
Membership_StartDT Datetime Not Null,
Membership_EndDt Datetime NULL,
Total_outstanding money Default 0
);
GO 
--Task 1.2.A
--SP to List out Items with matching title, Recent YOP(YearOfPublication) 
--and/or ItemType from Library.Items table records 
--Takes 3 inputs Title, Type and All for CurrentStatus: 1 means All('Available','On Loan','Removed','Lost') , 0 means 'Available'
 CREATE OR ALTER PROCEDURE Library.usp_Show_Item
@title as nvarchar(100), @type as nvarchar(15)  =NULL,@all as int=0
AS
BEGIN	
	IF(@all = 1)
	BEGIN
		--Display All CurrentStatus
		SELECT * FROM Library.Items where ItemTitle like '%'+@title+'%'  and 
		ItemType like '%'+IIF(@type IS NULL, '','%'+@type+'%' ) 	order by yop desc; 
	 END
	 ELSE
	 BEGIN
		--Display only CurrentStatus='Available' 
		SELECT * FROM Library.Items where ItemTitle like '%'+@title+'%'  and 
		ItemType like '%'+IIF(@type IS NULL, '','%'+@type+'%' ) and
		lower(CurrentStatus) IN ('available') 	order by yop desc; 
	 END
END;
GO

--Task 1.2.B
--StoredProcedure to return List of all Items On Loan that has due date(LoanEndDT) 
--less than of 5 days from the Current System Date.
CREATE OR ALTER PROCEDURE Library.usp_LoanEndsWithin5Days
AS
BEGIN
SELECT a.Itemid, a.Itemtitle,a.CurrentStatus, b.LoanID, b.LoanStartDT, b.LoanEndDt,
d.MemberID, d.FirstName
FROM Library.items a INNER JOIN Library.Loans b on a.ItemID=b.ItemID 
INNER JOIN Library.MemberLoans c on c.LoanID=b.LoanID 
INNER JOIN Library.Members d on d.MemberID = c.MemberID
WHERE DATEDIFF(DAY,GETDATE(),b.LoanEndDt ) BETWEEN 0 AND 5 
AND b.ReturnDT IS NULL ORDER BY b.LoanEndDt;
END;
GO

--ADB: TASK 1.2.C
--StoredProcedure to Insert a new Member record into Library.Members Table
CREATE OR ALTER PROCEDURE Library.uspAddMember
@username NVARCHAR(40),
@password NVARCHAR(20),
@firstname NVARCHAR(40),
@lastname NVARCHAR(40),
@dob date, 
@email NVARCHAR(100),
@phone NVARCHAR(20),
@addressid int = NULL,
@address1 NVARCHAR(50) = NULL,
@address2 NVARCHAR(50) = NULL,
@city NVARCHAR(50) = NULL,
@postcode NVARCHAR(10) = NULL,
@memshipstartdt datetime = NULL,
@memshipenddt datetime = NULL
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION
	DECLARE @salt UNIQUEIDENTIFIER=NEWID()
	IF (@addressid is NULL)
	BEGIN
		INSERT INTO Library.Addresses(Address1,Address2,City,Postcode) 
		VALUES(@address1,@address2,@city,@postcode)
	END	

	INSERT INTO Library.Members (Username,PwdHash,Salt,FirstName,LastName,
			DOB,Email,Telephone,AddressID,Membership_StartDT,Membership_EndDt)
		VALUES( IIF( LEN(@username ) > 40, 
				SUBSTRING(REPLACE(TRIM(@username ),';',''), 0,39 ), REPLACE(TRIM(@username ),';','')),		
			HASHBYTES('SHA2_512', @password+CAST( @salt AS NVARCHAR(36))), 
			@salt,
			IIF( LEN(@firstname ) > 40, 
				SUBSTRING(REPLACE(TRIM(@firstname ),';',''), 0,39 ), REPLACE(TRIM(@firstname ),';','')),
			IIF( LEN(@lastname ) > 40, 
				SUBSTRING(REPLACE(TRIM(@lastname ),';',''), 0,39 ), REPLACE(TRIM(@lastname ),';','')),
			@dob, @email, @phone,
			IIF(@addressid IS NULL,(SELECT IDENT_CURRENT('Library.Addresses') as addidentity), @addressid),
			IIF(@memshipstartdt IS NULL, GETDATE(), @memshipstartdt), 
			IIF(@memshipstartdt IS NULL, DATEADD(DAY, 365 ,GETDATE()), 
					IIF(@memshipenddt IS NULL , DATEADD(DAY, 365 ,@memshipstartdt), @memshipenddt) ) );
	COMMIT TRANSACTION 
	PRINT('Member added Successfully!' )
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() 
				RAISERROR(@ErrMsg, @ErrSeverity, 1)
END CATCH
END;
GO

--ADB: TASK 1.2.D
--StoredProcedure to Update/Edit the details of the existing Member in the Library.Members Table
CREATE OR ALTER PROCEDURE Library.uspEditMember
@memberid INT,
@username NVARCHAR(40) = NULL,
@password NVARCHAR(20) = NULL,
@firstname NVARCHAR(40)= NULL,
@lastname NVARCHAR(40)= NULL,
@dob date = NULL, 
@email NVARCHAR(100)= NULL,
@phone NVARCHAR(20)= NULL,
@addressid int = NULL,
@address1 NVARCHAR(50) = NULL,
@address2 NVARCHAR(50) = NULL,
@city NVARCHAR(50) = NULL,
@postcode NVARCHAR(10) = NULL,
@memshipstartdt datetime = NULL,
@memshipenddt datetime = NULL
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION
	DECLARE @cmdstr   NVARCHAR(300) 
	DECLARE @x int	
	--Update is achieved by forming Update Command String @cmdstr
	SET @cmdstr='UPDATE Library.Members SET '
	SET @x =0	
	--Check if username given
	IF @username IS NOT NULL	 
	BEGIN
		  SET @cmdstr= @cmdstr + ' Username='''+ IIF( LEN(@username ) > 40, 
				SUBSTRING(REPLACE(TRIM(@username ),';',''), 0,39 ), REPLACE(TRIM(@username ),';','')) +''''
		  SET @x =@x + 1
	END
	
	--Check if password given
	IF @password IS NOT NULL	 
	BEGIN
	BEGIN TRY
		--PwdHash and Salt are updated seperatly to avoid Arithmetic overflow 
		--error whene converting expression to data type nvarchar while forming the Command string
		BEGIN TRANSACTION
			DECLARE @salt UNIQUEIDENTIFIER=NEWID()		 
			UPDATE Library.Members SET 
			PwdHash=HASHBYTES('SHA2_512', @password+CAST( @salt AS NVARCHAR(36))), 
			Salt=@salt  WHERE MemberID= @memberid ;
		 COMMIT TRANSACTION
		 --PRINT('Password Updated Successfully for the Member!' )
	END TRY
	BEGIN CATCH
	--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg1 nvarchar(4000), @ErrSeverity1 int 
				SELECT 	@ErrMsg1 = ERROR_MESSAGE(), @ErrSeverity1 = ERROR_SEVERITY() 
				RAISERROR(@ErrMsg1, @ErrSeverity1, 1)
	END CATCH
	END	

	--Check if FirstName given
	IF (@firstname IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + 'FirstName='''+  IIF( LEN(@firstname ) > 40, 
				SUBSTRING(REPLACE(TRIM(@firstname ),';',''), 0,39 ), REPLACE(TRIM(@firstname ),';','')) +''''
		  SET @x =@x + 1
	END

	--Check if Lastname given
	IF (@lastname IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') +' LastName='''+  IIF( LEN(@lastname ) > 40, 
				SUBSTRING(REPLACE(TRIM(@lastname ),';',''), 0,39 ), REPLACE(TRIM(@lastname ),';','')) + ''''
		  SET @x =@x + 1
	END
	--Check if DOB given
	IF (@dob IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' DOB='''+CONVERT(NVARCHAR, @dob)  + ''''
		  SET @x =@x + 1
	END

	--Check if Email given
	IF (@email IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' Email='''+  TRIM(@email) +''''
		  SET @x =@x + 1
	END
	
	--Check if Telephone given
	IF (@phone IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' Telephone='''+  TRIM(@phone ) +''''
		  SET @x =@x + 1
	END
	
	--Check if AddressID given
	IF (@addressid IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' AddressID='+  CONVERT(NVARCHAR, @addressid) 
		  SET @x =@x + 1
	END
	
	--Check if AddressID is NULL but Address1, City and Postcode are given(Not NULL) then Update the address in the Addresses Table
	IF (@addressid IS NULL AND @address1 IS NOT NULL AND @city IS NOT NULL AND @postcode IS NOT NULL )
	BEGIN
	BEGIN TRY
	BEGIN TRANSACTION
			-- UPDATE Library.Addressess 
			DECLARE @memaddressid int
			 SET @memaddressid = (SELECT AddressID from Library.Members where MemberID =@memberid)
			UPDATE Library.Addresses SET Address1=REPLACE(TRIM(@address1),';',''),
			Address2=REPLACE(TRIM(@address2),';',''),City=REPLACE(TRIM(@city),';',''),
			Postcode=REPLACE(TRIM(@postcode),';','') WHERE AddressID=@memaddressid ;					
		COMMIT TRANSACTION 
		PRINT('Address Updated Successfully for the Member!' )
		END TRY		
		BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg2 nvarchar(4000), @ErrSeverity2 int 
				SELECT 	@ErrMsg2 = ERROR_MESSAGE(), @ErrSeverity2 = ERROR_SEVERITY() 
				RAISERROR(@ErrMsg2, @ErrSeverity2, 1)
		END CATCH
	END
	
	--Check if MembershipStartDT given
	IF (@memshipstartdt  IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + '  Membership_StartDT='''+  CONVERT(NVARCHAR, @memshipstartdt ) +''' '
		  SET @x =@x + 1
	END

	--Check if MembershipEndDT given
	IF (@memshipenddt  IS NOT NULL)
	BEGIN
		  SET @cmdstr= @cmdstr + IIF(@x>0,',','') + '  Membership_EndDT='''+  CONVERT(NVARCHAR, @memshipenddt ) +''' '
		  SET @x =@x + 1
	END
	 
	IF @x > 0
	BEGIN
		SET @cmdstr= @cmdstr + ' WHERE MemberID='+trim(str(@memberid))+';'	
		EXEC (@cmdstr)
		print(@cmdstr)
	END
	 --Displaying Update Command for Test, will be made hidden during deployment	
	COMMIT TRANSACTION 
	PRINT('Member Details Updated Successfully!' )
END TRY
BEGIN CATCH
	--If error exist! 
	IF @@TRANCOUNT > 0 
	BEGIN
		ROLLBACK TRANSACTION 
		DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
		SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() 
		RAISERROR(@ErrMsg, @ErrSeverity, 1)
	END
END CATCH
END;
GO

--ADB: TASK 1.3.1
--View for Loan history with Required information
--LoanID,MemberID, Firstname, ItemID, Title, Type, ItemStatus, BorrowDate, 
--Due date, Actual ReturnDate with FineAmt, Repaid amount, Loan_Outstanding and Total_Outstanding 
 CREATE OR ALTER VIEW Library.LoanHistoryView(LoanID, MemberID, 
Member_FirstName,ItemID, ItemTitle, ItemType, ItemStatus, BorrowDate,Duedate,ActualReturnDate, 
FineAmount,RepaidAmount, Loan_Outstanding, Total_Outstanding)
AS
SELECT A.LoanID, B.MemberID,B.Firstname, C.ItemID, C.ItemTitle, C.ItemType,  C.CurrentStatus,
A.LoanStartDt, A.LoanEndDt, A.ReturnDt, A.FineAmt, A.RepaidAmt, 
(A.FineAmt - A.RepaidAmt) as Loan_Outstanding,B.Total_outstanding from 
Library.Loans A INNER JOIN Library.MemberLoans D ON A.LoanID=D.LoanID 
INNER JOIN Library.Members B ON D.MemberID =B.MemberID 
INNER JOIN Library.Items C ON A.ItemID=C.ItemID;
GO

--ADB: TASK 1.3.2
--LoanID,MemberID, Firstname, ItemID, Title, Type, ItemStatus, BorrowDate, 
--Due date, Actual ReturnDate with FineAmt, Repaid amount, Loan_Outstanding and Total_Outstanding 
--with Rank on Total_Outstanding.
--View for Loan history with Rank on calculated Total_Outstanding  of each Member
CREATE OR ALTER VIEW Library.LoanHistoryRankView(LoanID, MemberID, 
Member_FirstName,ItemID, ItemTitle, ItemType, ItemStatus, BorrowDate,Duedate,ActualReturnDate, 
FineAmount,RepaidAmount,  Loan_Outstanding, Total_Outstanding, Balance_Rank)
AS
(SELECT A.LoanID, B.MemberID,B.Firstname, C.ItemID, C.ItemTitle, C.ItemType,  C.CurrentStatus,
A.LoanStartDt, A.LoanEndDt, A.ReturnDt, A.FineAmt, A.RepaidAmt, 
(A.FineAmt - A.RepaidAmt) as Loan_Outstanding, B.Total_Outstanding,
RANK() OVER (ORDER BY  B.Total_Outstanding DESC) AS Rank 
from Library.Loans A INNER JOIN Library.MemberLoans D ON A.LoanID=D.LoanID 
INNER JOIN Library.Members B ON D.MemberID =B.MemberID 
INNER JOIN Library.Items C ON A.ItemID=C.ItemID);
GO

--ADB: TASK 1.4
--Trigger to update the Specific item's Current Status to 'Available' only when ReturnDt if NOT Null
--This is triggered when updating the LOANS Table. Accoding to this TASK1, this trigger 't_item_status' 
--gets triggered while calling any of the the Procedures 
--1) Library.usp_ReturnItem and 2)Library.uspAddRepayment
DROP TRIGGER IF EXISTS Library.t_item_status;
GO
CREATE OR ALTER TRIGGER Library.t_item_status ON  Library.Loans
AFTER UPDATE
AS 
BEGIN
BEGIN TRY
	BEGIN TRANSACTION	 	
		DECLARE @itemid INT
		DECLARE @loanid INT
		--Get LoanID and ItemID
		SELECT @itemid= ItemID  from inserted
		SELECT @loanid= LoanID  from inserted
	 	--Updating the Specific item's Current Status to 'Available' only when ReturnDT IS NOT NULL
		UPDATE Library.Items SET CurrentStatus='Available' 	
		FROM Library.Items A INNER JOIN Library.Loans B ON	A.Itemid = B.itemid 
		WHERE A.ItemID= @itemid  AND B.LoanID= @loanid AND B.ReturnDT IS NOT NULL ;	
	    COMMIT TRANSACTION	   
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

--ADB: TASK 1.5.1
--Function to Display Count of Total number of Loans on a Specific date  
CREATE OR ALTER FUNCTION Library.udf_LoansCount(@LoanDate as datetime)
 RETURNS TABLE
 AS 
 RETURN
 (SELECT  Count(*)  as LoanCount from Library.Loans
WHERE   CONVERT(DATE,LoanStartDt) =CONVERT(DATE,@LoanDate));
GO

--ADB: TASK 1.5.2
--Function to Display Loans with their details on a Specific Date.
CREATE OR ALTER FUNCTION Library.udf_LoansOn(@LoanDate as datetime)
 RETURNS TABLE
 AS 
 RETURN
 (
 SELECT A.LoanID, B.MemberID,B.Firstname, C.ItemID, C.ItemTitle, C.ItemType,  
A.LoanStartDt, A.LoanEndDt, A.ReturnDt, A.FineAmt, A.RepaidAmt, 
(A.FineAmt - A.RepaidAmt) as OutstandingBalanceAmt,
RANK() OVER (ORDER BY  (A.FineAmt - A.RepaidAmt) DESC) AS Rank 
from Library.Loans A INNER JOIN Library.MemberLoans D ON A.LoanID=D.LoanID 
INNER JOIN Library.Members B ON D.MemberID =B.MemberID 
INNER JOIN Library.Items C ON A.ItemID=C.ItemID 
WHERE CONVERT(DATE,A.LoanStartDt)=CONVERT(DATE,@LoanDate));
GO

--ADB: TASK 1.6: Inserting records into the tables: Members, Items, Loans and Repayments 
--and Checking the codes from TASK 1.2 to 1.5

--Task 1.6.1: Testing Task1.2.C
--uspAddMember : Adding New Members through StoredProcedure call
EXEC Library.uspAddMember @username='User001', @password ='12345', @firstname ='James', @lastname ='William',
@dob ='1975-07-21', @email ='james@gmail.com', @phone ='0782378273', @address1='21 Oliver Street',
@address2 ='Oldham', @city ='Manchester', @postcode ='0L8566', @memshipstartdt  ='2022-10-05', @memshipenddt  = '2023-10-04'; 
GO

EXEC Library.uspAddMember @username='User002', @password ='45sara', @firstname ='Sara', @lastname ='Jane', 
@dob ='1980-10-15',  @email ='sara1980@gmail.com', @phone ='072432432', @address1='3 liverpool street',
@address2 ='Salford', @city ='Manchester', @postcode ='M65H6', @memshipstartdt  ='2022-05-20', @memshipenddt  = '2023-05-19';
GO

EXEC Library.uspAddMember @username='User003', @password ='Lina343', @firstname ='Lina', @lastname ='Mary',
@dob ='1975-02-09', @email ='lina787@yahoo.com', @phone ='075756765', @addressid= 1;
GO

EXEC Library.uspAddMember @username='User004', @password ='mathewdan343', @firstname ='Mathew', @lastname ='Daniel',
@dob ='1995-06-18',  @email ='danielmathew@gmail.com', @phone ='075475474',  @address1='54 Rose garden ',
@address2 ='Bolton', @city ='Manchester', @postcode ='BL1 1AS', @memshipstartdt  ='2023-01-10', @memshipenddt  = '2024-01-09';
GO

EXEC Library.uspAddMember @username='User005', @password ='anna4534', @firstname ='Anna', @lastname ='Ruby',
@dob ='1987-11-23',  @email ='rubynov23@hotmail.com', @phone ='073434234',  @address1='22 Lake street ',
@address2 ='Swinton', @city ='Manchester', @postcode ='M270AQ'; 
GO

EXEC Library.uspAddMember @username='User006', @password ='Mohamd332', @firstname ='Mohammed', @lastname ='Arif',
@dob ='1996-12-07', @email ='mdarif@gmail.com', @phone ='075475474',  @address1='9 kenns street ', @address2 ='Bolton',
@city ='Manchester', @postcode ='BL1 2ES', @memshipstartdt  ='2023-03-21', @memshipenddt  = '2024-03-20';
GO

EXEC Library.uspAddMember @username='User007', @password ='tensor', @firstname ='Kavin', @lastname ='Sunil',
@dob ='2001-06-24', @email ='sunilk@gmail.com', @phone ='075454354',  @address1='21 Gains bro avenue',
@address2 ='Oldham', @city ='Manchester', @postcode ='Ol833'; 
GO

SELECT * FROM Library.Members;
GO
SELECT * FROM Library.Addresses;
GO

--Testing Task1.2.D
--Task1.6.2: Editing Members details by calling procedure LIBRARY.uspEditMember  
--Member changing password and their Address details
EXEC LIBRARY.uspEditMember @memberid='1004', @password='12345',
@address1='15-A James residence;', @address2='Rose; Street', @city='Salford;', @postcode='M56EH';
GO
--Membership is transfered to another person within their family. So, No address change
EXEC LIBRARY.uspEditMember @memberid='1003',@firstname='George;', @lastname='Abraham;',
@dob='1990-06-28', @phone ='075900034', @email='George.a@gmail.com';
GO
--Member changing EmailID
EXEC LIBRARY.uspEditMember @memberid='1006',@email='sunil.kumar@hotmail.com';
GO
--Membership Renewal
EXEC LIBRARY.uspEditMember @memberid='1001',@memshipstartdt='2023-04-01', @memshipenddt='2024-03-31';
GO

Select * from Library.Members where username ='User0005' and pwdhash=HASHBYTES('SHA2_512', '12345'+CAST( salt AS NVARCHAR(36)));
GO

--Task 1.6.3: Stored procedure to add ITEMS and inserting ITEMS.
--Task1.6.3.1: StoredProcedure to Insert new Item/Catalogue into LIBRARY.ITEMS Table
CREATE OR ALTER PROCEDURE Library.uspAddItem
@title NVARCHAR(100),
--0 for Book, 1 for Journal, 2 for DVD, else Others
@type int = 0,
@author NVARCHAR(50),
@yop NVARCHAR(4),
@isbn NVARCHAR(20),
@addedDT datetime = NULL 
--CurrentStatus By Default is 'Available' during INSERT
--Note: 0 for Available, 1 for Loan, 2 for Overdue, 3 for Removed, 4 for Lost 
--Record RemovedDT for currentStatus = 3 or 4
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION 		 
	 INSERT INTO Library.Items (ItemTitle,ItemType, Author, YOP, ISBN,AddedDt)
		VALUES(IIF( LEN(@title) > 100, SUBSTRING(REPLACE(TRIM(@title),';',''), 0,99 ), REPLACE(TRIM(@title),';','')),
		CASE WHEN @type =0 THEN 'Book' WHEN @type = 1 THEN 'Journal' WHEN @type =2 THEN 'DVD'  ELSE 'Other' END,
		IIF( LEN(@author) > 50, SUBSTRING(REPLACE(TRIM(@author),';','') , 0, 49 ), REPLACE(TRIM(@author),';','') ),
		TRIM(@yop),  REPLACE(TRIM(@isbn),';',''), 
		IIF(@addedDT IS NULL, GETDATE(), @addedDT) );		
	COMMIT TRANSACTION 
	PRINT('Item added Successfully!' )
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END; 
GO

--Task1.6.3.2: Adding Items through Procedure Calls
--0 for Book, 1 for Journal, 2 for DVD, else Others
Exec Library.uspAddItem @title ='Distributed Database Management Systems: A Practical Approach',
@type = 0, @author ='Rahimi, Saeed K Haug; Frank S', @yop ='2010',
@isbn ='9786612707612', @addedDT ='2021-01-01'; 
GO
 Exec Library.uspAddItem @title ='Data Science from Scratch', @type = 0, @author ='Joel Grus', 
 @yop ='2015', @isbn ='9781491901427', @addedDT ='2022-01-01';
GO
Exec Library.uspAddItem @title =' Data Science for Business	 ',  @type = 2, 
@author ='Foster Provost, Tom Fawcett', @yop ='2013', @isbn ='978-1449361327;', @addedDT ='2022-01-01';
 GO
 Exec Library.uspAddItem  @title =' Spark: The Definitive Guide;	 ', @type = 0,
@author ='Bill Chambers, Matei Zaharia', @yop ='2018', @isbn ='978-1491912218;', @addedDT ='2022-01-01';
 GO
  Exec Library.uspAddItem  @title =' Learning Spark, 2nd Edition;	 ',  @type = 0, 
 @author ='Jules S, Damji, Brooke Wenig & Denny Lee', @yop ='2020', @isbn ='978-1492050049;',
@addedDT ='2023-01-01';
GO
--0 for Book, 1 for Journal, 2 for DVD, else Others
 Exec Library.uspAddItem @title =' Database Systems: A Practical Approach to Design, Implementation, and Management ',
 @type = 0, @author ='	Thomas Connolly, Carolyn Begg', @yop ='2015', @isbn ='978-1-292-06118-4;',
@addedDT ='2022-01-01';
  GO
Exec Library.uspAddItem @title =' Fundamentals of Database Systems ', @type = 0, 
@author ='Elmasri , R. and Navathe , S.B.N.',  @yop ='2011', @isbn ='978-0-136-08620-8',
@addedDT ='2022-01-01';
GO
Exec Library.uspAddItem
@title =' Database Processing Fundamentals, Design, and Implementation ', @type = 0,
@author ='David M. Kroenke and David J. Auer', @yop ='2013', @isbn ='978-0133876703 ',
@addedDT ='2022-01-01';
GO
Exec Library.uspAddItem @title ='Developing network configuration management database system and its application ', @type =1, 
@author ='Yamada, Hiroshi; Yada, Takeshi, Nomura, Hiroto', @yop ='2013', 
@isbn ='1572-9451 ', @addedDT ='2022-01-01';
GO
--0 for Book, 1 for Journal, 2 for DVD, else Others
Exec Library.uspAddItem  @title ='Big Data ', @type =2, @author ='Chartier; Tim', @yop ='2014',
@isbn ='6726052 '; 
GO
Exec Library.uspAddItem  @title ='Big data : algorithms, analytics, and applications',  @type =0, 
@author ='Li, Kuan-Ching', @yop ='2015', @isbn ='0-367-57595-7 ';
 GO
 --0 for Book, 1 for Journal, 2 for DVD, else Others
 Exec Library.uspAddItem
@title ='Mass data processing and multidimensional database management based on deep learning	',
@type =1, @author ='Shen, Haijie Li, Yangyuan; Tian, Xinzhi ; Chen, Xiaofan', @yop ='2022',
@isbn ='2299-1093 '; 
GO

--Task1.6.4 Adding Loans through Procedure calls
--Two Store procedures are used 1) Library.uspAddLoan and 2) Library.usp_UpdateTotalOutStanding

--Task1.6.4.1: Additional StoredProcedure to update Total_OutStanding for the Specific Member(MemberID)
--This SP is Called by other 3 SPs 1) Library.uspAddLoan and 2) Library.usp_ReturnItem 3)Library.uspAddRepayment 
--and by one trigger 4)Library.t_Member_delete_stream
CREATE OR ALTER PROCEDURE Library.usp_UpdateTotalOutStanding
@memid as int
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION	 			
	UPDATE Library.Members SET 
	Library.Members.Total_outstanding = CalFine.Outstanding
	FROM Library.Members  MEM INNER JOIN 
	(SELECT C.MemberID, sum(A.FineAmt - A.RepaidAmt) AS Outstanding 
	FROM Library.Loans A INNER JOIN Library.MemberLoans B ON A.LoanID =B.LoanID  
	INNER JOIN Library.Members C on B.MemberID = C.MemberID 
	group by  C.MemberID having C.MemberId=@memid) as CalFine on MEM.MemberID  = CalFine.MemberID 
	Print(CONVERT(NVARCHAR,@memid) +' Member Total_Outstanding Updated Successfully in the Members Table!')
 COMMIT TRANSACTION
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

--Task1.6.4.2: Library.uspAddLoan is a Stored Procedure to Insert new Loan into Library.Loans table
--This accepts itemid, memberid. loanstartdt  and period. Loanstartdt & Period are optional(default is 7days)
--Checks member's membership_Enddt and Item's CurrentStatus from relevant tables
--Creates loan only when 1)Membershipdate is not expired and 2)Item is Available.
CREATE OR ALTER PROCEDURE Library.uspAddLoan
@memberid int,
@itemid int  ,
@loanStartDT datetime= NULL,
@period int= NULL
--LoanPeriod int NOT NULL DEFAULT 7,
--LoanEndDT datetime is NULL during insert,
--ReturnDT is NULL during insert
--FineAmt money Default 0
--RepaidAmt money Default 0 
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION 		 
	--Checking Member's Membership_EndDt and Item's CurrentStatus before creating the Loan
	DECLARE @memshipEndDT datetime
	DECLARE @itemstatus nvarchar(10)
	SET @memshipEndDT = (SELECT Membership_EndDt from Library.Members where MemberID =@memberid)
	PRINT('Membership End date is ' + CONVERT(NVARCHAR,@memshipEndDT) 
				+ ' for Member with MemberID: '+ CONVERT(NVARCHAR,@memberid))
	SET @itemstatus = (SELECT CurrentStatus from Library.items where ItemID=@itemid)
	PRINT('Item with ItemID: '+ CONVERT(NVARCHAR,@itemid)+' is  '+ trim(@itemstatus))
	IF DATEDIFF(DAY, GETDATE(),@memshipEndDT ) > 0 and @itemstatus = 'Available'
	BEGIN
	DECLARE @enddate  datetime
	DECLARE @fine money
	SET @fine =0
	--LoanEndDt is calculated w.r.to LoanStartDt and Period,
	SET @enddate =	IIF(@period IS NULL, DATEADD(DAY, 7 ,IIF(@loanStartDT IS NULL, GETDATE(), @loanStartDT )) , 
	DATEADD(DAY, @period , IIF(@loanStartDT IS NULL, GETDATE(), @loanStartDT )) ) 
	--Fine Calculation for Predated LoanEndDate
	IF DATEDIFF(DAY,@enddate , GETDATE()) > 0
	BEGIN
		SET @fine = DATEDIFF(DAY,@enddate , GETDATE()) * 0.10	
	END
	
	INSERT INTO Library.Loans (ItemID,LoanStartDT, LoanPeriod, LoanEndDT,FineAmt)
		VALUES(@itemid, IIF(@loanStartDT IS NULL, GETDATE(), @loanStartDT ),
		--if Period is not given then add 7days By Default to  Currentdate
		IIF(@period IS NULL, 7,@period),
		--LoanEndDt is calculated w.r.to LoanStartDt and Period, 
		@enddate,@fine );
		  --Add new record in MemberLoans Table for @memberid
		  INSERT INTO Library.MemberLoans(MemberID,LoanID) 
		  VALUES(@memberid,(SELECT IDENT_CURRENT('Library.Loans') as addidentity) );
		  PRINT('Loan Created successsfully for Member with MemberID: '+ CONVERT(NVARCHAR,@memberid) )
		  --Update Item record's CurrentStatus to Available
		  UPDATE Library.Items SET CurrentStatus='On Loan' WHERE ItemID=@itemid ;	
		  PRINT('Now, Item with ItemID: '+CONVERT(NVARCHAR,@itemid) +' is Updated to ''on Loan'' Status' )
		  --Call SP to update Total_OutStanding for the Specific Member
		  EXEC Library.usp_UpdateTotalOutStanding @memid = @memberid
		  PRINT('SELECT * FROM Library.udf_LoansOn(GETDATE());')
	END

	ELSE
	BEGIN
		IF @itemstatus != 'Available'
		BEGIN
			PRINT(CONVERT(NVARCHAR,@itemid)+' Item is '+ @itemstatus +'. Hence, Member cannot borrow this Item')
		END
		IF DATEDIFF(DAY, GETDATE(),@memshipEndDT ) < 0
		BEGIN			
			PRINT('Membership Date is Expired: ' +CONVERT(NVARCHAR,@memshipEndDT) 
					+' for Member with MemberID: '+ CONVERT(NVARCHAR,@memberid))
			PRINT('Hence, Member cannot borrow Item anymore!' )
		END
	END	
	COMMIT TRANSACTION 
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

EXEC Library.uspAddLoan @itemid=110, @memberid =1002;
GO

EXEC Library.uspAddLoan @itemid=110, @memberid =1003;
--Item Already on Loan
GO

EXEC Library.uspAddLoan @itemid=103, @memberid =1003, @period =30, @loanStartDT='2023-03-25';
GO

EXEC Library.uspAddLoan @itemid=102, @memberid =1000, @period =10,  @loanStartDT='2023-04-10';
GO
EXEC Library.uspAddLoan @itemid=105, @memberid =1000, @period =14,  @loanStartDT='2023-04-10';
GO
EXEC Library.uspAddLoan @itemid=104, @memberid =1004, @loanStartDT='2023-04-19';
GO
EXEC Library.uspAddLoan @itemid=108, @memberid =1000;
GO
EXEC Library.uspAddLoan @itemid=100, @memberid =1006, @loanStartDT='2023-03-20';
GO


--Task1.6.5 Returning Loan Items
--StoredProcedure to Update ReturnDT in Loans table when Item is Returned
--1)Calculates fine, if any. 2)Calls Library.usp_UpdateTotalOutStanding 
--to update Total_Outstanding of that Member
--3)triggers the Trigger t_item_status to Change Item Status to 'Available'
CREATE OR ALTER PROCEDURE Library.usp_ReturnItem 
@loanid as int
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION	 	
	--Calculates and Updates FineAmt and ReturnDT for Specific LoanID
		UPDATE Library.Loans SET FineAmt= DATEDIFF(DAY,LoanEndDT , GETDATE()) * 0.10,	
		  ReturnDT=GETDATE()	WHERE LoanID=@loanid 	
		Print('Item return Is Updated Successfully in the Loans Table!')
		DECLARE @memberid INT
	    SET @memberid =	(SELECT MemberID from Library.MemberLoans where LoanID =@loanid)
		EXEC Library.usp_UpdateTotalOutStanding @memid = @memberid
	COMMIT TRANSACTION
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

--Explained in report under TASK1.7.1
--StoredProcedure to Calculates Fines of All the Loans with NULL ReturnDT and beyond Duedate(LoanEndDT)
--and Updates the sum of all Fine balances in the Total_outstanding of all Members with Non-returned loans
--Thus, Updates All Fine-outstandings in LOANS and MEMBERS Tables 
--This Stored-Procedure Needs to be executed once everyday.
CREATE OR ALTER PROCEDURE Library.usp_UpdateLoanFines
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION
		--Updating FineAmt of Loans which is with NULL ReturnDT and beyond Duedate(LoanEndDT)
		UPDATE Library.Loans SET FineAmt= DATEDIFF(DAY,LoanEndDT , GETDATE()) * 0.10	
		WHERE DATEDIFF(DAY,LoanEndDT , GETDATE()) > 0 AND ReturnDT IS NULL
		--Updating Outstanding column of Members Table by summing
		--the Balances (FineAmt - RepaidAmt) of each loans in LoansTable for each Member 
		UPDATE Library.Members SET 
		Library.Members.Total_outstanding = CalFine.Outstanding
		FROM Library.Members  MEM INNER JOIN 
		(SELECT C.MemberID, sum(A.FineAmt - A.RepaidAmt) AS Outstanding 
		FROM Library.Loans A INNER JOIN Library.MemberLoans B ON A.LoanID =B.LoanID  
		INNER JOIN Library.Members C on B.MemberID = C.MemberID 
		group by  C.MemberID ) as CalFine on MEM.MemberID  = CalFine.MemberID 		
		Print('ALL Outstanding Balances Updated Successfully!')
	COMMIT TRANSACTION
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

EXEC  Library.usp_ReturnItem @loanid=3;
GO
EXEC Library.usp_UpdateLoanFines;
GO
--Task1.6.6 Adding Fine Repayment into the Repayments Table through Procedure calls
--StoredProcedure to Insert Repayments by getting LoanId, Amount and
--PaymentType  optional(Default is Cash)
--Amount will also be added to respective RepaidAmount of Loans table
--Also, calls Library.usp_UpdateTotalOutStanding for updating Total_outstanding in Members'table
CREATE OR ALTER PROCEDURE Library.uspAddRepayment
@loanid int,
@amount as money,
@type as nvarchar(4) = NULL
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION 		
	--Add record to REPAYMENTS Table
	IF @type IS NULL
	BEGIN
		INSERT INTO Library.Repayments(LoanID,PaymentDT, Amount)
		VALUES(@loanid,  GETDATE(), @amount );
	END
	ELSE
	BEGIN
		INSERT INTO Library.Repayments(LoanID,PaymentDT, Amount, PaymentType)
		VALUES(@loanid,  GETDATE(), @amount, @type);
	END
	
   --Update REPAIDAMT of the relevant loan in the LOANS table 
	UPDATE Library.Loans SET RepaidAmt= RepaidAmt + @amount 
		WHERE LoanID=@loanid;
	--Update the TOTAL_OUTSTANDING of the relevant member in MEMBERS table
	DECLARE @memberid INT
	SET @memberid =	(SELECT MemberID from Library.MemberLoans where LoanID =@loanid)
	EXEC Library.usp_UpdateTotalOutStanding @memid = @memberid
	Print('Repayment Done Successfully for LoanID ' + TRIM(STR(@LoanID)) + ' !')
	COMMIT TRANSACTION 
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

EXEC Library.uspAddRepayment @loanid=3,@amount=0.5, @type='Card';
GO
EXEC  Library.usp_ReturnItem @loanid=2;
GO
EXEC Library.uspAddRepayment @loanid=2,@amount=0.1;
GO

EXEC  Library.usp_ReturnItem @loanid=7;
GO
EXEC Library.uspAddRepayment @loanid=7,@amount=3, @type='Card';
GO
SELECT * FROM Library.Repayments;
GO



--Task1.6.8: Showing the result of execution of 2a, 2b, 3, 4, 5
--Task1.6.8.1 Testing of  of Task 1.2.A
EXEC Library.usp_Show_Item @title='database', @all=1
GO
EXEC Library.usp_Show_Item @title='database'
GO
EXEC Library.usp_Show_Item @title='database' , @type='book';
GO

EXEC Library.usp_Show_Item @title='data' , @type='journal',@all=1;
GO
EXEC Library.usp_Show_Item @title='spark' , @type='book', @all=1;
GO
EXEC Library.usp_Show_Item @title='data' , @type='dvd';
GO
--Task1.6.8.2 Testing of  of Task 1.2.B
EXEC Library.usp_LoanEndsWithin5Days ;
GO
--Task1.6.8.3 Testing of  of Task 1.3
SELECT * FROM Library.LoanHistoryView ;
GO
SELECT * FROM Library.LoanHistoryRankView ;
GO


--Task1.6.8.4 Testing of  of Task 1.4

--Task1.6.8.5 Testing of  of Task 1.5
SELECT * FROM Library.udf_LoansOn('2023-04-24');
SELECT * FROM Library.udf_LoansCount('2023-04-24');
SELECT * FROM Library.udf_LoansOn(GETDATE());
GO
--Task1.7 FOUR Additional database objects useful 
--for a basic Library Management DatabaseSystem
--Task1.7.1
--Library.usp_UpdateLoanFines 
--(SP CODE APEARS AFTER THE SP CODE Library.usp_ReturnItem IN THE SAME FILE)

--Task1.7.2
--Created MembersArchive table and two triggers for Deleting a Member 
--to Archive/Backup deleted member data
--and create trigger for member delete to store Member data in Memberarchive
--Trigger t_Member_delete_stream Deletes MEMBERS record
--when No Open-loan exist(No unreturnedItem) for that member. If exist then Checks for Total_Outstanding and 
-- Deletes records from MEMBERS  and MEBERLOANS Only when there is No Outstanding dues
--Else It shows error
DROP TRIGGER IF EXISTS  Library.t_Member_delete_stream;
GO
CREATE OR ALTER TRIGGER  Library.t_Member_delete_stream ON Library.Members
INSTEAD OF DELETE
AS 
BEGIN
BEGIN TRY
	BEGIN TRANSACTION	
	DECLARE @memberid INT;
	DECLARE @outstanding MONEY;
	DECLARE @count INT;
	DECLARE @count_unreturnedItems INT;
	SELECT @memberid = MemberID FROM DELETED;
	EXEC Library.usp_UpdateTotalOutStanding @memid = @memberid
	SELECT @outstanding =Total_outstanding FROM DELETED;
	SELECT @count = COUNT(*) FROM Library.MemberLoans WHERE MemberID = @memberid;
	PRINT('Total_Outstanding = '+ CONVERT(NVARCHAR,@outstanding))
	SELECT @count_unreturnedItems =COUNT(*) FROM Library.Loans A INNER JOIN Library.MemberLoans B ON
			A.LoanID = B.LoanID INNER JOIN Library.Members C ON
			C.MemberID = B.MemberID where C.MemberID = @memberid AND A.ReturnDT IS NULL;
	PRINT('Total_Unreturned Loan Items = '+ CONVERT(NVARCHAR,@count_unreturnedItems))
	IF @count = 0
	BEGIN
	    PRINT(TRIM(STR(@memberid))  +' MEMBER HAS NO LOAN. MEMBER RECORD DELETED!')		
		DELETE FROM Library.Members WHERE MemberID = @memberid;
	END
	ELSE
	BEGIN
		IF @outstanding > 0.00
		BEGIN
			THROW 50000, 'Cannot delete the Member! Because there is an outstanding due amount yet to be paid! ', 1;
		END
		IF @count_unreturnedItems > 0
		BEGIN
			THROW 50000, 'Cannot delete the Member! Because there are Some Unreturned Loan Items! ', 1;
		END
		IF @outstanding <= 0.00 AND @count_unreturnedItems = 0
		BEGIN			
			DELETE FROM Library.MemberLoans WHERE MemberID = @memberid;
			DELETE FROM Library.Members WHERE MemberID = @memberid;		
			PRINT( 'MEMBER WITH MEMBERID ' + TRIM(STR(@memberid))  +'  DELETED SUCCESSFULLY!')	
		END
	END
	COMMIT TRANSACTION	  
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 		
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);				
END CATCH
END;
GO

--After, When Members details are deleted from MEMBERS through t_Member_delete_stream 
--then the following Trigger t_Member_DeleteArchive backups the Deleted Members's Data
--to the MEMBERSARCHIVE table
DROP TRIGGER IF EXISTS Library.t_Member_DeleteArchive;
GO
CREATE  OR ALTER TRIGGER Library.t_Member_DeleteArchive ON Library.Members
AFTER DELETE
AS BEGIN
INSERT INTO Library.MembersArchive
(MemberID, Username, FirstName, LastName, DOB, Email, Telephone, AddressID,
 Membership_StartDT, Membership_EndDt,   Total_outstanding)
SELECT
d.MemberID,  d.Username, d.FirstName, d.LastName, d.dob, d.Email,d.Telephone,
d.AddressID, d.Membership_StartDT, d.Membership_EndDt, d.Total_outstanding
FROM
deleted d
End;
GO

Delete Library.Members where MemberID=1006;
GO
Delete Library.Members where MemberID=1001;
GO
 
SELECT * FROM Library.MembersArchive;
GO
 
--Task1.7.3 Editing/Updating Items
--StoredProcedure to Update/Edit Item in the Library.Items table  
CREATE OR ALTER PROCEDURE Library.uspEditItem
@itemid int,
@title NVARCHAR(100)= NULL,
--0 for Book, 1 for Journal, 2 for DVD, else Others
@type int = NULL,
@author NVARCHAR(50) = NULL,
@yop NVARCHAR(4) = NULL,
@isbn NVARCHAR(20)= NULL,
@addedDT datetime = NULL,
@cstatus NVARCHAR(10) = NULL,
--CurrentStatus By Default   is Available while INSERT
--Could be changed during UPDATE 
--0 for Available, 1 for Loan, 2 for Overdue, 3 for Removed, other for Lost 
--Item RemovedDT for currentStatus = 3 or 4
@removeDT datetime = NULL
AS
BEGIN
BEGIN TRY
	BEGIN TRANSACTION 		 
	DECLARE @cmdstr   NVARCHAR(300) 
	DECLARE @x int
	--Update is achieved by forming Command String
	SET @cmdstr='UPDATE Library.Items SET '
	SET @x =0
	IF @title IS NOT NULL	 
	BEGIN
		  SET @cmdstr= @cmdstr + ' ItemTitle='''+ IIF( LEN(@title) > 100, 
			SUBSTRING(REPLACE(TRIM(@title),';',''), 0,99 ), REPLACE(TRIM(@title),';','')) +''''
		  SET @x =@x + 1
	END
	IF @type IS NOT NULL	 
	BEGIN
		SET @cmdstr= @cmdstr  + IIF(@x>0,',','') + ' ItemType=''' +CASE WHEN @type =0 
			THEN 'Book' WHEN @type = 1 THEN 'Journal' WHEN @type =2 THEN 'DVD'   ELSE 'Other'  END +''''
		SET @x =@x + 1		 
	END
	IF @author IS NOT NULL	
	BEGIN
		SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' Author='''+IIF( LEN(@author) > 50, 
			SUBSTRING(REPLACE(TRIM(@author),';','') , 0, 49 ), REPLACE(TRIM(@author),';','') )+''''
		SET @x =@x + 1		 
	END
	IF @yop IS NOT NULL 
	BEGIN
		SET @cmdstr= @cmdstr  + IIF(@x>0,',','') + ' YOP='''+TRIM(@yop) +''''
		SET @x =@x + 1		 
	END
	IF @isbn IS NOT NULL  
	BEGIN
		SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' ISBN=''' + REPLACE(TRIM(@isbn),';','')+''''
		SET @x =@x + 1		
	END
	IF @addedDT IS  NOT NULL  	
	BEGIN		 
		SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' AddedDT=''' + 
			IIF(CONVERT(NVARCHAR,@addedDT )  IS NULL, CONVERT(NVARCHAR,GETDATE() ), 
			CONVERT(NVARCHAR, @addedDT ) )+''''
		SET @x =@x + 1		
	END
	IF @cstatus IS NOT NULL  	
	BEGIN		 
		--0 for Available, 1 for Loan, 2 for Overdue, 3 for Removed, 4 for Lost   		
		SET @cmdstr= @cmdstr + IIF(@x>0,',','') + ' CurrentStatus=''' + 
			CASE WHEN @cstatus =0 THEN 'Available' WHEN @cstatus = 1 THEN 'On Loan' WHEN @cstatus =2 
			THEN 'Overdue'  WHEN @cstatus =3 THEN 'Removed' WHEN @cstatus =4 THEN 'Lost' END +''''
		SET @x =@x + 1		
		IF @cstatus  > 2  
		--Item Record RemovedDT for currentStatus = 3 or 4 (Removed or Lost)
		BEGIN
			SET @cmdstr= @cmdstr + ',RemovedDT='''+ IIF(CONVERT(NVARCHAR,@removeDT )  IS NULL, 
				CONVERT(NVARCHAR,GETDATE()),  CONVERT(NVARCHAR,@removeDT )) +''''			   
		END
	 END
	 SET @cmdstr= @cmdstr + ' WHERE ItemID='+trim(str(@itemid))+';'
	 --Displaying Command string for Test Purpose
	 print(@cmdstr)
	 EXEC (@cmdstr)
	COMMIT TRANSACTION 
	PRINT('Item Details Updated Successfully!' )
END TRY
BEGIN CATCH
			--If error exist! 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION 
				DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int 
				SELECT 	@ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY() ;
				RAISERROR(@ErrMsg, @ErrSeverity, 1);
END CATCH
END;
GO

EXEC Library.uspEditItem @ITEMID=100, @cstatus=4;
GO

--Task 1.7.4 
--Function returns the Total_Outstanding of a Specific Member accepting MEMBERID
CREATE OR ALTER FUNCTION Library.udf_Outstanding(@memberid as int)
RETURNS money
AS
BEGIN
Declare @balance as money
Set @balance =(SELECT Total_Outstanding as Total_OutStanding from Library.Members where MemberID=@memberid)
RETURN (@balance);
END;
GO
SELECT  Library.udf_Outstanding(1000) as Outstanding;
GO

SELECT * FROM Library.udf_LoansCount(GETDATE());
GO
SELECT * FROM Library.udf_LoansOn(GETDATE());
GO
SELECT * FROM Library.udf_LoansCount('2023-04-10');
GO
SELECT * FROM Library.udf_LoansOn('2023-04-10');
GO

SELECT * FROM Library.udf_LoansOn('2023-04-10');
 GO

----Regular Backup before the END-OF-DAY
----WITH CHECKSUM option in the backup command used to ensures 
----Successfull restoration of DB during restore command
--BACKUP DATABASE SalfordCityLibrary
--TO DISK = 'C:\ADB_2023\SalfordCityLibrary_20230426check.bak' WITH CHECKSUM;
--GO


----Restore with VERIFYONLY and CHECKSUM options 
----ensures that BackUp is not corrupted and also for flawless Restoration.
--RESTORE VERIFYONLY
--FROM DISK = 'C:\ADB_2023\SalfordCityLibrary_20230426check.bak' WITH CHECKSUM;
--GO
 
-- RESTORE DATABASE SalfordCityLibrary
--FROM DISK = 'C:\ADB_2023\SalfordCityLibrary_20230426check.bak'
--WITH REPLACE, RECOVERY, STATS = 10;
--GO
--Select statement during Member's Online-Login
--Verifying Member's Online Login credentials with Membership_EndDT  
SELECT * FROM  Library.Members WHERE 
username='User006' and PwdHash=HASHBYTES('SHA2_512',  'Mohamd332' +CAST( salt AS NVARCHAR(36)))
and Membership_EndDt > GETDATE();
GO
 SELECT * FROM Library.LoanHistoryView ;
GO
SELECT * FROM Library.LoanHistoryRankView;
GO