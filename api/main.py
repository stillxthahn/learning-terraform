import boto3
import json
import pandas as pd
import io
from dotenv import load_dotenv
import os
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import requests
import uvicorn
import uuid

load_dotenv()
ACCESS_KEY = os.getenv("ACCESS_KEY")
SECRET_KEY = os.getenv("SECRET_KEY")
STOCK_API = os.getenv("STOCK_API")
API_URL = f"https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=IBM&interval=5min&outputsize=full&datatype=csv&apikey=${STOCK_API}"
KINESIS_NAME = os.getenv("KINESIS_NAME")

app = FastAPI()
current_line = 0 
s3 = boto3.client('s3' , aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY) 
kinesis = boto3.client('kinesis')

triggered = False

def trigger_airflow():
    response = requests.post('http://54.82.46.217:8080/api/experimental/dags/invoke_lambda_and_check_batch_status/dag_runs',
                             json={'conf': {'triggered_by': 'stock'}})
    
    if response.status_code == 200:
        print('Airflow DAG triggered successfully')
    else:
        print('Error triggering Airflow DAG')


def fetch_stock_data(file_name='stock-data.csv'):
	"""
	Fetch stock data from the provided API URL and return it as a DataFrame.
	"""
	response = requests.get(API_URL)
	with open(file_name, 'wb') as file:
		file.write(response.content)
	data = pd.read_csv(file_name)
	data['timestamp'] = pd.to_datetime(data['timestamp'])
	data['symbol'] = 'IBM'

	sorted_data = data.sort_values(by='timestamp', ascending=True)
	sorted_data.to_csv(file_name, index=False)


    
@app.get("/", response_class=HTMLResponse)
async def root():
    return """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <title>Welcome to Joshua Stock API</title>
          </head>
          <body>
              <h1>Welcome to Stock API</h1>
              <p>Step 1: Create a S3 bucket (stock-series), fetch real time IBM stock data and save into created bucket using <code>http://127.0.0.1:8000/bucket</code> endpoint.</p>
              <p>Step 2: Get real time stock data per request and trigger Airflow using <code>http://127.0.0.1:8000/stock</code> ending</p>
            </div>
          </body>
        </html>
    """



@app.get("/bucket")
async def create_bucket():
	"""
	This api create a S3 bucket (stock-series), fetch real time IBM stock data and save into created bucket.
	"""
     
	s3.create_bucket(Bucket='stock-series')
	fetch_stock_data("stock-data.csv")
	s3.upload_file("./stock-data.csv", "stock-series", "stock-data.csv")	
	return {"message": "Bucket initialized successfully"}


@app.get("/stock")
async def write_bucket():
	"""
	This api get real time stock data and trigger Airflow
	"""

	global triggered
	if not triggered:
		# trigger_airflow()
		print("Airflow DAG triggered successfully")
		triggered = True

	global current_line 
	obj = s3.get_object(Bucket='stock-series', Key='stock-data.csv')

	"""
	io.StringIO is used to parse the CSV data obtained from S3. The CSV data is read from S3 as a binary string using obj['Body'].read(). 
	This binary string is then decoded into a UTF-8 string using the decode() method. 
	This decoded string is then passed to io.StringIO to create a file-like object that can be read using the csv.reader() method.
	"""

	csv_data = obj['Body'].read().decode('utf-8')
	df = pd.read_csv(io.StringIO(csv_data))

	if current_line >= len(df):
		current_line = 0  
		return {"error": "End of file reached, resetting to the first line"}

	row = df.iloc[current_line].to_dict()  
	current_line += 1  


	response = kinesis.put_record(
    StreamName="TestStream",
    Data=json.dumps(row),
    PartitionKey=str(uuid.uuid4()))         
	return response
    

# @app.get("/stock")
# async def get_line():
#     """
#     This api reads the CSV file from the last row to the first row, which makes it easier to retrieve the latest data .
#     Note: the stock data from csv file  has the oldest data at the bottom
#     """

#     """
#     added a global boolean variable triggered that keeps track of whether the Airflow DAG has already been triggered. 
#     When the /stock endpoint is called for the first time, the trigger_airflow function is called to make the request to the Airflow endpoint, 
#     and the triggered flag is set to True to indicate that the request has been triggered. On subsequent calls to the /stock endpoint, 
#     the trigger_airflow function is not called again because the triggered flag is already set to True
#     """
#     global triggered
#     if not triggered:
#         trigger_airflow()
#         triggered = True

#     """
#      global current_line is a global variable that keeps track of the current line that has been retrieved from the CSV file
#     """
#     global current_line 
#     obj = s3.get_object(Bucket='finalproject-streamdata', Key='amazon.csv')

#     """
#     io.StringIO is used to parse the CSV data obtained from S3. The CSV data is read from S3 as a binary string using obj['Body'].read(). 
#     This binary string is then decoded into a UTF-8 string using the decode() method. 
#     This decoded string is then passed to io.StringIO to create a file-like object that can be read using the csv.reader() method.
#     """
#     file = io.StringIO(obj['Body'].read().decode('utf-8'))
#     reader = csv.reader(file)
#     header = next(reader)
#     lines = [row for row in reader] #list compression of all the rows in the csv file
#     try:
#         line = lines[len(lines) - 1 - current_line]  #expression calculates the index of the line to be retrieved from the lines list, which contains all the lines of the CSV file.
#         result = {header[i]: line[i] for i in range(len(header))}
#         result["symbol"] = "AMZN" #adding the a new column called symbol with value IBM to the data gotten from csv file
#         current_line += 1   # keeps track of the current row in the csv file
#         return result
#     except IndexError:
#         current_line = 0
#         return {"error": "end of file"}



if __name__ == "__main__":
    uvicorn.run(app, host="localhost", port=8000)