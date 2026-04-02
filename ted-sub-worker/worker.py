#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import glob
import sys
import subprocess
import boto3
from pymongo import MongoClient
from datetime import datetime

# =========================
# CONFIG
# =========================
WORK_DIR = "/tmp/subtitles"
S3_BUCKET = "ted-video-dataset-2026-alv"

# MongoDB config (tuoi dati da Glue)
MONGO_URI = "mongodb+srv://ted_user:ICxk4Gv2fRmTFzq5@cluster0.yxb8l1z.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
MONGO_DB = "ted_video_db"
MONGO_COLLECTION = "videos"

VIDEO_ID = os.getenv("VIDEO_ID")
VIDEO_URL = os.getenv("VIDEO_URL")

if not VIDEO_ID or not VIDEO_URL:
    print("❌ Errore: VIDEO_ID e VIDEO_URL devono essere passati come variabili d'ambiente")
    sys.exit(1)

os.makedirs(WORK_DIR, exist_ok=True)

# Client S3
if os.getenv('AWS_ACCESS_KEY_ID'):
    session = boto3.Session(
        aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        aws_session_token=os.getenv('AWS_SESSION_TOKEN'),
        region_name=os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
    )
    s3_client = session.client('s3')
else:
    s3_client = boto3.client('s3')

# Client MongoDB
print("🔗 Connessione a MongoDB...")
mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
db = mongo_client[MONGO_DB]
collection = db[MONGO_COLLECTION]


def aggiorna_status(status, **extra_fields):
    """Aggiorna lo stato del video su MongoDB"""
    update_data = {"subtitle_status": status}
    update_data.update(extra_fields)

    try:
        result = collection.update_one(
            {"id": VIDEO_ID},
            {"$set": update_data}
        )
        if result.matched_count == 0:
            print(f"⚠️ Nessun documento trovato con id={VIDEO_ID}")
            return False
        print(f"✅ MongoDB aggiornato: status={status}")
        return True
    except Exception as e:
        print(f"❌ Errore aggiornamento MongoDB: {e}")
        return False


def scarica_sottotitoli():
    """Scarica i sottotitoli inglesi con yt-dlp"""
    print(f"📥 Scaricando sottotitoli per VIDEO_ID={VIDEO_ID}")

    output_template = os.path.join(WORK_DIR, f"{VIDEO_ID}.%(ext)s")

    cmd = [
        "yt-dlp",
        "--write-subs",
        "--sub-langs", "en",
        "--skip-download",
        "--output", output_template,
        VIDEO_URL
    ]

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=WORK_DIR,
            text=True,
            encoding="utf-8",
            errors="ignore"
        )
        stdout, stderr = process.communicate()

        print(stdout)
        if process.returncode != 0:
            print(f"❌ Errore yt-dlp:\n{stderr}")
            return False

        print("✅ Sottotitoli scaricati")
        return True

    except FileNotFoundError:
        print("❌ yt-dlp non trovato nel container")
        return False


def trova_file_vtt():
    pattern = os.path.join(WORK_DIR, "*.en.vtt")
    files = glob.glob(pattern)
    if files:
        return files[0]
    return None


def converti_in_txt(file_vtt):
    print(f"🔄 Convertendo: {os.path.basename(file_vtt)}")

    try:
        with open(file_vtt, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"❌ Errore lettura file: {e}")
        return None

    lines = content.split("\n")
    righe_pulite = []

    # Prima passata: tieni solo il testo
    for line in lines:
        line = line.strip()

        if not line:
            continue
        if line.startswith("WEBVTT"):
            continue
        if "-->" in line:
            continue
        if re.match(r"^\d+$", line):
            continue
        if re.match(r"^\d{2}:\d{2}:\d{2}", line):
            continue
        if line.startswith("NOTE") or line.startswith("STYLE"):
            continue

        clean_line = re.sub(r"<[^>]+>", "", line)
        clean_line = re.sub(r"&nbsp;", " ", clean_line)
        clean_line = re.sub(r"&amp;", "&", clean_line)
        clean_line = re.sub(r"&lt;", "<", clean_line)
        clean_line = re.sub(r"&gt;", ">", clean_line)

        if clean_line.strip():
            righe_pulite.append(clean_line)

    # Seconda passata: unisci righe che continuano la frase
    testo_finale = []

    for i, riga in enumerate(righe_pulite):
        if i == 0:
            testo_finale.append(riga)
        else:
            riga_precedente = righe_pulite[i - 1]

            if riga and riga[0].islower():
                testo_finale.pop()
                riga_unita = riga_precedente + " " + riga
                testo_finale.append(riga_unita)
                righe_pulite[i] = riga_unita
            else:
                testo_finale.append(riga)

    # Terza passata: rimuovi duplicati consecutivi
    testo_senza_dup = []
    riga_prec = ""

    for riga in testo_finale:
        if riga.strip() != riga_prec.strip():
            testo_senza_dup.append(riga)
            riga_prec = riga

    file_output = os.path.join(WORK_DIR, f"{VIDEO_ID}.txt")

    try:
        with open(file_output, "w", encoding="utf-8") as f:
            f.write("\n".join(testo_senza_dup))
        print(f"✅ File TXT creato: {file_output}")
        print(f"📄 Righe estratte: {len(testo_senza_dup)}")
        return file_output
    except Exception as e:
        print(f"❌ Errore salvataggio TXT: {e}")
        return None


def carica_su_s3(file_txt):
    """Carica il file TXT su S3"""
    s3_key = f"transcripts/{VIDEO_ID}.txt"

    try:
        s3_client.upload_file(file_txt, S3_BUCKET, s3_key)
        print(f"✅ File caricato su S3: s3://{S3_BUCKET}/{s3_key}")
        return s3_key
    except Exception as e:
        print(f"❌ Errore upload S3: {e}")
        return None


def leggi_testo_completo(file_txt):
    """Legge il contenuto del file TXT"""
    try:
        with open(file_txt, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print(f"❌ Errore lettura testo: {e}")
        return ""


def elimina_file_vtt(file_vtt):
    try:
        os.remove(file_vtt)
        print(f"🗑️ VTT eliminato: {file_vtt}")
    except Exception as e:
        print(f"⚠️ Errore eliminazione VTT: {e}")


def main():
    print("=" * 60)
    print("🎬 TED Subtitle Worker - v2.0")
    print("=" * 60)
    print(f"VIDEO_ID: {VIDEO_ID}")
    print(f"VIDEO_URL: {VIDEO_URL}")
    print()

    # Verifica connessione Mongo
    try:
        mongo_client.admin.command('ping')
        print("✅ MongoDB connesso")
    except Exception as e:
        print(f"❌ MongoDB non raggiungibile: {e}")
        sys.exit(1)

    # Scarica sottotitoli
    if not scarica_sottotitoli():
        aggiorna_status("error", error_message="yt-dlp failed")
        sys.exit(1)

    file_vtt = trova_file_vtt()
    if not file_vtt:
        print("❌ Nessun file .vtt trovato (sottotitoli non disponibili)")
        aggiorna_status("error", error_message="No subtitles available")
        sys.exit(1)

    print(f"📁 File trovato: {file_vtt}")

    # Converte in TXT
    file_txt = converti_in_txt(file_vtt)
    if not file_txt:
        aggiorna_status("error", error_message="Conversion failed")
        sys.exit(1)

    # Leggi testo per MongoDB
    transcript_text = leggi_testo_completo(file_txt)
    word_count = len(transcript_text.split())
    print(f"📝 Word count: {word_count}")

    # Carica su S3
    s3_key = carica_su_s3(file_txt)
    if not s3_key:
        print("❌ Upload S3 fallito")
        aggiorna_status("error", error_message="S3 upload failed")
        sys.exit(1)

    # Aggiorna MongoDB con SUCCESSO
    success = aggiorna_status(
        "done",
        transcript_text=transcript_text,
        transcript_lang="en",
        transcript_available=True,
        transcript_s3_key=s3_key,
        transcript_word_count=word_count,
        transcript_completed_at=datetime.utcnow()
    )

    if not success:
        print("❌ Fallito aggiornamento finale MongoDB")
        sys.exit(1)

    # Pulizia
    elimina_file_vtt(file_vtt)

    print()
    print("🎉 Worker completato con SUCCESSO")


if __name__ == "__main__":
    main()