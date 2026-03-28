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
                'body': json.dumps({'error': "Parametro 'tit' obbligatorio per la ricerca tramite titolo"})
            }
        
        limit = int(query_params.get('limit', 10))
        limit = min(max(limit, 1), 50)
        
        # Ottieni la collezione (connessione in cache)
        collection = dbconn.get_connection(DB_NAME, COLLECTION_NAME)
        
        search_words = search_term.split()
        
        if len(search_words) > 1:
            should_conditions = []
            for word in search_words:
                should_conditions.append({
                    'text': {
                        'query': word,
                        'path': 'title',
                        'fuzzy': {'maxEdits': 1}
                    }
                })
            
            pipeline = [
                {
                    '$search': {
                        'index': 'title_search_index',
                        'compound': {
                            'should': should_conditions,
                            'minimumShouldMatch': 1
                        }
                    }
                },
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
            ]
        else:
            pipeline = [
                {
                    '$search': {
                        'index': 'title_search_index',
                        'text': {
                            'query': search_term,
                            'path': 'title',
                            'fuzzy': {
                                'maxEdits': 2,
                                'prefixLength': 2
                            }
                        }
                    }
                },
                {
                    '$project': {
                        'title': 1,
                        'description': 1,
                        'speaker': 1,
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