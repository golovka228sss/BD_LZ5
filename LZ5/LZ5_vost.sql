USE master;
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

USE master;
GO

CREATE OR ALTER PROCEDURE sp_RestoreUserActions
    @BackupFilePath NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT name FROM sys.databases WHERE name = N'User_Actions')
    BEGIN
        ALTER DATABASE User_Actions SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END

    DECLARE @DefaultDataPath NVARCHAR(500) = (SELECT CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500)));
    DECLARE @DefaultLogPath NVARCHAR(500) = (SELECT CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(500)));

    DECLARE @MdfTarget NVARCHAR(500) = @DefaultDataPath + 'User_Actions.mdf';
    DECLARE @LdfTarget NVARCHAR(500) = @DefaultLogPath + 'User_Actions_log.ldf';

    BEGIN TRY
        RESTORE DATABASE User_Actions
        FROM DISK = @BackupFilePath
        WITH REPLACE,
        MOVE 'User_Actions' TO @MdfTarget,
        MOVE 'User_Actions_log' TO @LdfTarget;

        ALTER DATABASE User_Actions SET MULTI_USER;
        PRINT 'База данных успешно восстановлена из бэкапа: ' + @BackupFilePath;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT name FROM sys.databases WHERE name = N'User_Actions')
        BEGIN
            ALTER DATABASE User_Actions SET MULTI_USER;
        END
        PRINT 'Произошла ошибка в процессе восстановления базы данных!';
        THROW;
    END CATCH
END;
GO

USE master;
GO

EXEC sp_RestoreUserActions @BackupFilePath = N'C:\Program Files\Microsoft SQL Server\MSSQL17.DISASTER\MSSQL\Backup\User_Actions_2025.bak';
GO


USE User_Actions;
GO

SELECT name AS [Логическое имя], physical_name AS [Физический путь на диске]
FROM sys.database_files;
GO