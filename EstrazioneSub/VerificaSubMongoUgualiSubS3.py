"""
dopo aver creato i file cosi
mongo
const fs = require("fs"); const path = process.env.USERPROFILE + "\\Desktop\\mongo_ids.txt"; const ids = db.videos.find({ subtitle_status: "done" }, { id: 1, _id: 0 }).toArray().map(doc => doc.id).join("\\n"); fs.writeFileSync(path, ids); print("Salvato in: " + path); print("Totale ID: " + ids.split("\\n").length);

s3-powershell
aws s3 ls s3://ted-video-dataset-2026-alv/transcripts/ --recursive | ForEach-Object { ($_ -split "\\s+")[-1] } | ForEach-Object { ($_ -split "/")[-1] -replace "\\.txt$","" } | Sort-Object | Out-File "$HOME\\Desktop\\s3_ids.txt"
"""
import re

def read_ids(filepath):
    """Legge ID da file, uno per riga"""
    ids = set()

    # Prova più encoding possibili
    for enc in ["utf-8", "utf-16", "utf-16-le", "cp1252"]:
        try:
            with open(filepath, 'r', encoding=enc) as f:
                for line in f:
                    clean = line.strip().strip('"\'')
                    if clean and not clean.lower().startswith('id'):
                        match = re.search(r'\d+', clean)
                        if match:
                            ids.add(match.group())
            return ids
        except UnicodeDecodeError:
            continue

    raise ValueError(f"Impossibile leggere il file: {filepath}")

# Leggi entrambi i file
s3_ids = read_ids(r"C:\Users\Utente\Desktop\s3_ids.txt")
mongo_ids = read_ids(r"C:\Users\Utente\Desktop\mongo_ids.txt")

print("\n" + "="*50)
print("RISULTATI")
print("="*50)
print(f"ID su S3:           {len(s3_ids)}")
print(f"ID 'done' su Mongo: {len(mongo_ids)}")

# Trova differenze
missing_in_mongo = s3_ids - mongo_ids
extra_in_mongo = mongo_ids - s3_ids

if missing_in_mongo:
    print(f"\nIN S3 MA NON IN MONGODB 'done': {len(missing_in_mongo)}")
    for vid in sorted(missing_in_mongo):
        print(f"   {vid}")

if extra_in_mongo:
    print(f"\nIN MONGODB 'done' MA NON IN S3: {len(extra_in_mongo)}")
    for vid in sorted(extra_in_mongo)[:10]:
        print(f"   {vid}")

print("\n" + "="*50)