from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi

# Variabili globali per mantenere la connessione in cache
client = None

def get_connection(db_name, collection_name):
    global client
    
    if client is None:
        db_user = "app_user"
        db_pwd = "peJiXi217sdfODCA"
        uri = f"mongodb+srv://{db_user}:{db_pwd}@cluster0.yxb8l1z.mongodb.net/?appName=Cluster0"
        
        client = MongoClient(uri, server_api=ServerApi('1'))
        
        # Test connessione
        try:
            client.admin.command('ping')
            print("Connessione a MongoDB stabilita")
        except Exception as e:
            print(f"Errore connessione: {e}")
            raise
    
    database = client[db_name]
    collection = database[collection_name]
    return collection