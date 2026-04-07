import json
import logging
import connect_to_db as dbconn

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DB_NAME = "ted_video_db"
COLLECTION_NAME = "videos"

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters', {})
        if not query_params:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': "Nessun parametro per la ricerca e' stato passato..."})
            }
        
        search_term = query_params.get('q')
        if not search_term:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': "Parametro 'q' obbligatorio per la ricerca"})
            }
        
        # Limite impostato di default a 10 se non specificato
        limit = int(query_params.get('limit', 10))
        limit = min(max(limit, 1), 50)
        
        # Leggiamo il parametro della durata inviato dall'app Flutter (in secondi)
        max_duration = query_params.get('max_duration')
        
        collection = dbconn.get_connection(DB_NAME, COLLECTION_NAME)
        
        # 1. Costruiamo la base della pipeline (ricerca full-text)
        pipeline = [
            {
                '$search': {
                    'index': 'default_search_index',
                    'compound': {
                        'should': [
                            {'text': {'query': search_term, 'path': 'title', 'score': {'boost': {'value': 3}}}},
                            {'text': {'query': search_term, 'path': 'speakers', 'score': {'boost': {'value': 2}}}},
                            {'text': {'query': search_term, 'path': 'tags', 'score': {'boost': {'value': 1.5}}}},
                            {'text': {'query': search_term, 'path': 'description', 'score': {'boost': {'value': 1}}}}
                        ]
                    }
                }
            }
        ]

        # 2. Aggiungiamo il filtro per la durata SOLO se è stato passato il parametro
        if max_duration is not None:
            try:
                max_duration_int = int(max_duration)
                pipeline.append({
                    '$match': {
                        'duration': {'$lte': max_duration_int}
                    }
                })
            except ValueError:
                logger.warning(f"Valore max_duration non valido ignorato: {max_duration}")

        # 3. Completiamo la pipeline con proiezione e limite
        pipeline.extend([
            {
                '$project': {
                    'title': 1,
                    'description': 1,
                    'speakers': 1,
                    'presenterdisplayname': 1,
                    'url': 1,
                    'tags': 1,
                    'duration': 1,
                    'publishedat': 1,
                    'images': 1,
                    'score': {'$meta': 'searchScore'}
                }
            },
            {'$limit': limit}
        ])
        
        results = list(collection.aggregate(pipeline))
        
        for result in results:
            if '_id' in result:
                result['_id'] = str(result['_id'])
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'query': search_term,
                'count': len(results),
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Errore: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
