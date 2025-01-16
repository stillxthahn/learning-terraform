import pandas as pd
import mysql.connector
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import requests
import uvicorn

API_URL = f"https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=IBM&interval=5min&outputsize=full&datatype=csv&apikey=4I3GM8BWYMYZZO28"

app = FastAPI()
current_line = 0 

CREATE_TABLE_QUERY = """
CREATE TABLE IBM_STOCK (
    time DATETIME NOT NULL,
    open FLOAT NOT NULL,
    high FLOAT NOT NULL,
    low FLOAT NOT NULL,
    close FLOAT NOT NULL,
    volume FLOAT NOT NULL,
    symbol VARCHAR(40),
    event_time DATETIME DEFAULT NOW(),
    PRIMARY KEY (time)
);
"""

INSERT_QUERY = """
INSERT IGNORE INTO IBM_STOCK (time, open, high, low, close, volume, symbol)
VALUES (%s, %s, %s, %s, %s, %s, %s);
"""

mysql_connection = mysql.connector.connect(
	host="mysql",
	port=3306,
	user="root",
	password="root",
	database="STOCK_STREAMING")

mysql_connection.cursor().execute(f"""SHOW TABLES LIKE 'IBM_STOCK'""")
result = mysql_connection.fetchone()

if result:
	print("Table 'IBM_STOCK' already exists.")
else:
	mysql_connection.execute(CREATE_TABLE_QUERY)
	mysql_connection.commit()
	print("Table 'IBM_STOCK' has been created successfully.")


    
@app.get("/", response_class=HTMLResponse)
async def root():
    return """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <title>Welcome to stillxthahn_ Stock API</title>
          </head>
          <body>
              <h1>Welcome to Stock API</h1>
              <p>Step 1: Fetch real time IBM stock data and save it into stock-data.csv<code>http://127.0.0.1:8000/fetch</code> endpoint.</p>
              <p>Step 2: Get real time stock data per request and insert it into database using <code>http://127.0.0.1:8000/stock</code> ending</p>
            </div>
          </body>
        </html>
    """


@app.get("/fetch")
async def fetch_data(file_name="stock-data.csv"):
	"""
	This api fetches real time IBM stock data and saves it into stock-data.csv
	"""
	response = requests.get(API_URL)
	with open(file_name, 'wb') as file:
		file.write(response.content)

	data = pd.read_csv(file_name)
	data['timestamp'] = pd.to_datetime(data['timestamp'])
	data['symbol'] = 'IBM'

	sorted_data = data.sort_values(by='timestamp', ascending=True)
	sorted_data.to_csv(file_name, index=False)
	return {"message": "Data initialized successfully"}


@app.get("/stock")
async def insert_database():
	"""
	This api gets real time stock data per request and inserts it into database
	"""

	global current_line 

	"""
	io.StringIO is used to parse the CSV data obtained from S3. The CSV data is read from S3 as a binary string using obj['Body'].read(). 
	This binary string is then decoded into a UTF-8 string using the decode() method. 
	This decoded string is then passed to io.StringIO to create a file-like object that can be read using the csv.reader() method.
	"""

	df = pd.read_csv("stock-data.csv")

	if current_line >= len(df):
		current_line = 0  
		return {"error": "End of file reached, resetting to the first line"}

	row = df.iloc[current_line].to_dict()  
	current_line += 1  
      

	# INSERT INTO DATABASE
	mysql_connection.execute(INSERT_QUERY, (
		row['time'],
		row['open'],
		row['high'],
		row['low'],
		row['close'],
		row['volume'],
		row['symbol']
	))
	mysql_connection.commit()

	return row
    


if __name__ == "__main__":
	
	uvicorn.run(app, host="localhost", port=8000)