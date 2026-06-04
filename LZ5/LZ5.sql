
USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'User_Actions')
BEGIN
    ALTER DATABASE User_Actions SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE User_Actions;
    PRINT 'Старая база данных User_Actions успешно удалена.';
END
GO

CREATE DATABASE User_Actions;
GO

USE User_Actions;
GO

CREATE PARTITION FUNCTION pf_Monthly (DATE)
AS RANGE RIGHT FOR VALUES (
    '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01', '2025-07-01', 
    '2025-08-01', '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01'
);
GO

CREATE PARTITION SCHEME ps_Monthly
AS PARTITION pf_Monthly
ALL TO ([PRIMARY]);
GO

CREATE TABLE User_Logs (
    id UNIQUEIDENTIFIER DEFAULT NEWID(),
    username NVARCHAR(100) NOT NULL,
    user_action NVARCHAR(100) NOT NULL,
    action_date DATE NOT NULL,
    action_time TIME NOT NULL,
    action_result NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_User_Logs_Partitioned PRIMARY KEY CLUSTERED (id, action_date)
) ON ps_Monthly(action_date);
GO

PRINT 'Начинается генерация 1 000 000 записей с защитой от переполнения INT...';
SET NOCOUNT ON;

;WITH DateRange AS (
    SELECT 
        CAST('2025-01-01' AS DATE) AS StartDate,
        CAST('2025-12-31' AS DATE) AS EndDate
),
Numbers AS (
    SELECT TOP (1000000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
    FROM sys.all_columns c1
    CROSS JOIN sys.all_columns c2
)
INSERT INTO User_Logs (id, username, user_action, action_date, action_time, action_result)
SELECT 
    NEWID() AS id,
    
    N'user_' + CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 500 + 1 AS NVARCHAR(10)) AS username, 
    
    CASE ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 4
        WHEN 0 THEN N'LOGIN'
        WHEN 1 THEN N'LOGOUT'
        WHEN 2 THEN N'VIEW_PAGE'
        ELSE N'UPDATE_PROFILE'
    END AS user_action,
    
    DATEADD(DAY, ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % (DATEDIFF(DAY, StartDate, EndDate) + 1), StartDate) AS action_date,
    TIMEFROMPARTS(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 24, ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 60, ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 60, 0, 0) AS action_time,
    
    CASE ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 2
        WHEN 0 THEN N'SUCCESS'
        ELSE N'FAILED'
    END AS action_result
FROM Numbers
CROSS JOIN DateRange;

PRINT 'Генерация успешно завершена! Ошибок переполнения больше нет.';
GO

SELECT 
    partition_number AS [Номер Секции (Месяц)], 
    rows AS [Количество строк]
FROM sys.partitions 
WHERE object_id = OBJECT_ID('User_Logs') AND index_id <= 1;
GO

USE master;
GO

BACKUP DATABASE User_Actions
TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL17.DISASTER\MSSQL\Backup\User_Actions_2025.bak'
WITH FORMAT,
     NAME = N'Full Backup of User_Actions';
GO
