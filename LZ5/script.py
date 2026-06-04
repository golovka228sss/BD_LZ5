import datetime
import pyodbc

SERVER_CONN = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=localhost\\DISASTER;"
    "Trusted_Connection=yes;"
)

def init_shards():
    """Создает 12 баз данных (шардов) и таблицы внутри них, если они не существуют."""
    conn = pyodbc.connect(SERVER_CONN, autocommit=True)
    cursor = conn.cursor()
    
    for month in range(1, 13):
        db_name = f"User_Shard_{month}"
        
        cursor.execute(f"""
            IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '{db_name}')
            BEGIN
                CREATE DATABASE {db_name};
            END
        """)
        
        cursor.execute(f"""
            USE {db_name};
            IF OBJECT_ID('User_Logs', 'U') IS NULL
            BEGIN
                CREATE TABLE User_Logs (
                    id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
                    username NVARCHAR(100) NOT NULL,
                    user_action NVARCHAR(100) NOT NULL,
                    action_date DATE NOT NULL,
                    action_time TIME NOT NULL,
                    action_result NVARCHAR(50) NOT NULL
                );
            END
        """)
        print(f"Шард {db_name} успешно проверен/создан.")
        
    cursor.close()
    conn.close()

def insert_to_shard(data):
    """Маршрутизирует запись в соответствующую базу данных на основе месяца."""
    action_date = datetime.datetime.strptime(data["action_date"], "%Y-%m-%d")
    shard_id = action_date.month
    db_name = f"User_Shard_{shard_id}"
    
    shard_conn_str = SERVER_CONN + f"Database={db_name};"
    conn = pyodbc.connect(shard_conn_str)
    cursor = conn.cursor()
    
    query = """
        INSERT INTO User_Logs (username, user_action, action_date, action_time, action_result)
        VALUES (?, ?, ?, ?, ?)
    """
    cursor.execute(
        query,
        (
            data["username"],
            data["user_action"],
            data["action_date"],
            data["action_time"],
            data["action_result"],
        ),
    )
    conn.commit()
    print(f"Запись пользователя {data['username']} успешно отправлена в шард {db_name} (Месяц: {shard_id})")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    init_shards()
    
    test_record = {
        "username": "sharded_disaster",
        "user_action": "RUN_PYTHON_SCRIPT",
        "action_date": "2025-05-20", 
        "action_time": "12:00:00",
        "action_result": "SUCCESS"
    }
    
    insert_to_shard(test_record)