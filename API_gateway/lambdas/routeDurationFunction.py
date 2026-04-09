import json
import os
import urllib.request
from urllib.error import HTTPError, URLError

def lambda_handler(event, context):
    try:
        # Recupero l'API Key dalle variabili d'ambiente
        api_key = os.environ.get('ORS_API_KEY')
        if not api_key:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Configurazione server mancante (API Key non trovata)'})
            }

        # 1. Verifica che i parametri esistano per evitare crash
        params = event.get('queryStringParameters')
        if not params:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Query string parameters mancanti'})
            }

        start_lat_str = params.get('startLat')
        start_lng_str = params.get('startLng')
        end_lat_str = params.get('endLat')
        end_lng_str = params.get('endLng')

        # 2. Validazione della presenza e conversione in float
        if not all([start_lat_str, start_lng_str, end_lat_str, end_lng_str]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Coordinate mancanti'})
            }

        try:
            start_lat = float(start_lat_str)
            start_lng = float(start_lng_str)
            end_lat = float(end_lat_str)
            end_lng = float(end_lng_str)
        except ValueError:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Le coordinate devono essere numeri validi'})
            }

        profile = params.get('profile', 'driving-car')
        url = f"https://api.openrouteservice.org/v2/directions/{profile}"

        # 3. Preparazione della richiesta HTTP POST
        headers = {
            'Authorization': api_key,
            'Content-Type': 'application/json'
        }

        payload = {
            "coordinates": [
                [start_lng, start_lat], # ORS richiede [Longitudine, Latitudine]
                [end_lng, end_lat]
            ]
        }
        
        # Codifico il payload in bytes
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers=headers, method='POST')

        # 4. Chiamata a OpenRouteService
        try:
            with urllib.request.urlopen(req) as response:
                response_body = response.read().decode('utf-8')
                response_data = json.loads(response_body)
                
                # Estrazione durata
                duration = response_data['routes'][0]['summary']['duration']

                return {
                    'statusCode': 200,
                    # Decommenta qui sotto se ti serve il CORS
                    # 'headers': {
                    #     'Access-Control-Allow-Origin': '*',
                    #     'Access-Control-Allow-Headers': 'Content-Type',
                    #     'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
                    # },
                    'body': json.dumps({'duration': duration})
                }

        # Gestione errori HTTP da parte di ORS (es. 400, 401, 404)
        except HTTPError as e:
            error_response = e.read().decode('utf-8')
            print(f"Errore ORS HTTP {e.code}: {error_response}")
            
            try:
                error_details = json.loads(error_response)
            except json.JSONDecodeError:
                error_details = error_response

            return {
                'statusCode': e.code,
                'body': json.dumps({
                    'error': 'Errore durante il calcolo del percorso',
                    'details': error_details
                })
            }

    # Gestione crash imprevisti del server
    except Exception as e:
        print(f"ERRORE INTERNO: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Errore interno del server',
                'message': str(e)
            })
        }
