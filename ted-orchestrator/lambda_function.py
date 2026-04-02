import json
import os
from pymongo import MongoClient
from datetime import datetime, timedelta
import boto3

MONGO_URI = "mongodb+srv://ted_user:ICxk4Gv2fRmTFzq5@cluster0.yxb8l1z.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
MONGO_DB = "ted_video_db"
MONGO_COLLECTION = "videos"

BATCH_JOB_QUEUE = "ted-sub-job-queue"
BATCH_JOB_DEFINITION = "ted-sub-job-def"

mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
db = mongo_client[MONGO_DB]
collection = db[MONGO_COLLECTION]


def get_batch_client(credentials=None):
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=credentials.get('AWS_SECRET_ACCESS_KEY'),
            aws_session_token=credentials.get('AWS_SESSION_TOKEN'),
            region_name='us-east-1'
        )
        return session.client('batch')
    return boto3.client('batch', region_name='us-east-1')


def lambda_handler(event, context):
    limit = event.get('limit', 10)
    aws_credentials = event.get('aws_credentials')
    batch_client = get_batch_client(aws_credentials)

    # Cerca video con status "pending" (da fare)
    # OPPURE "processing" bloccati da troppo tempo (probabilmente falliti)
    cutoff_time = datetime.utcnow() - timedelta(minutes=10)

    query = {
        "$or": [
            {"subtitle_status": "pending"},  # Da fare
            {
                "subtitle_status": "processing",
                "subtitle_started_at": {"$lt": cutoff_time}  # Bloccati
            }
        ]
    }

    videos = list(collection.find(query).limit(limit))
    print(f"🔍 Trovati {len(videos)} video da processare (pending o bloccati)")

    risultati = {
        "processati": [],
        "gia_completati": [],
        "errori": []
    }

    for video in videos:
        video_id = str(video['id'])
        url = video.get('url')

        if not url:
            print(f"❌ {video_id}: No URL")
            collection.update_one(
                {"id": video_id},
                {"$set": {"subtitle_status": "error", "error_message": "No URL"}}
            )
            risultati["errori"].append({"id": video_id, "motivo": "no_url"})
            continue

        # Doppio check: se ha già transcript, è done
        if video.get('transcript_text') and len(video['transcript_text']) > 100:
            print(f"✅ {video_id}: Già completato")
            collection.update_one(
                {"id": video_id},
                {"$set": {"subtitle_status": "done"}}
            )
            risultati["gia_completati"].append(video_id)
            continue

        print(f"🆕 {video_id}: Lancio job")

        # Lancia job Batch
        try:
            env_vars = [
                {'name': 'VIDEO_ID', 'value': video_id},
                {'name': 'VIDEO_URL', 'value': url},
            ]
            if aws_credentials:
                for key in ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN']:
                    if key in aws_credentials:
                        env_vars.append({'name': key, 'value': aws_credentials[key]})

            response = batch_client.submit_job(
                jobName=f"ted-sub-{video_id}",
                jobQueue=BATCH_JOB_QUEUE,
                jobDefinition=BATCH_JOB_DEFINITION,
                containerOverrides={'environment': env_vars}
            )

            job_id = response['jobId']
            print(f"   └─ Job lanciato: {job_id}")

            # Metti "processing" con timestamp
            collection.update_one(
                {"id": video_id},
                {"$set": {
                    "subtitle_status": "processing",
                    "subtitle_job_id": job_id,
                    "subtitle_started_at": datetime.utcnow()
                }}
            )

            risultati["processati"].append(video_id)

        except Exception as e:
            print(f"   └─ ❌ Errore lancio: {e}")
            collection.update_one(
                {"id": video_id},
                {"$set": {"subtitle_status": "error", "error_message": str(e)}}
            )
            risultati["errori"].append({"id": video_id, "motivo": str(e)})

    # Conta quanti rimangono in "pending"
    remaining_pending = collection.count_documents({"subtitle_status": "pending"})
    processing_count = collection.count_documents({"subtitle_status": "processing"})

    print(f"📊 Pending: {remaining_pending}, Processing: {processing_count}")

    return {
        "statusCode": 200,
        "body": {
            "processati_ora": len(videos),
            "continua": remaining_pending > 0 or processing_count > 0,
            "rimanenti_pending": remaining_pending,
            "in_processing": processing_count,
            "risultati": risultati
        }
    }