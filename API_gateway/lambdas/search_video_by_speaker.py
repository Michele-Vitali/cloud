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
                'body': json.dumps({'error': "Parametro 'speaker' obbligatorio per la ricerca tramite relatore"})
            }
        
        limit = int(query_params.get('limit', 10))
        limit = min(max(limit, 1), 50)
        
        collection = dbconn.get_connection(DB_NAME, COLLECTION_NAME)
        
        pipeline = [
            {
                '$search': {
                    'index': 'speaker_search_index',
                    'text': {
                        'query': search_term,
                        'path': 'speakers',
                        'fuzzy': {'maxEdits': 1}
                    }
                }
            },
            {
                '$project': {
                    'title': 1,
                    'description': 1,
                    'speakers': 1,
                    'tags': 1,
                    'video_url': 1,
                    'thumbnail_url': 1,
                    'duration': 1,
                    'score': {'$meta': 'searchScore'}
                }
            },
            {'$limit': limit}
        ]
        
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