#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import subprocess
import glob
import sys

# CONFIGURAZIONE
DESKTOP = os.path.join(os.path.expanduser("~"), "Desktop")
URL = "https://www.ted.com/talks/ben_proudfoot_the_true_story_of_the_iconic_tagline_because_i_m_worth_it_the_final_copy_of_ilon_specht"


def scarica_sottotitoli():
    """Scarica i sottotitoli in inglese con yt-dlp"""
    print("📥 Scaricando sottotitoli in inglese...")

    cmd = [
        "yt-dlp",
        "--write-subs",
        "--sub-langs", "en",
        "--skip-download",
        "--output", os.path.join(DESKTOP, "%(title)s.%(ext)s"),
        URL
    ]

    try:
        # Usa Popen invece di run per evitare problemi di encoding
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=DESKTOP,
            text=True,
            encoding='utf-8',
            errors='ignore'  # Ignora caratteri non decodificabili
        )
        stdout, stderr = process.communicate()

        if process.returncode != 0:
            print(f"❌ Errore yt-dlp: {stderr}")
            return None
        print("✅ Sottotitoli scaricati")
        return True
    except FileNotFoundError:
        print("❌ yt-dlp non trovato! Assicurati che sia installato e nel PATH")
        return None


def trova_file_vtt():
    """Trova il file .vtt scaricato sul desktop"""
    pattern = os.path.join(DESKTOP, "*.en.vtt")
    files = glob.glob(pattern)
    if files:
        return files[0]
    return None


def converti_in_txt(file_vtt):
    """Converte il file VTT in TXT pulito, unendo le righe che continuano la frase"""
    print(f"🔄 Convertendo: {os.path.basename(file_vtt)}")

    try:
        with open(file_vtt, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ Errore lettura file: {e}")
        return None

    lines = content.split('\n')
    righe_pulite = []

    # Prima passata: estrai solo il testo valido
    for line in lines:
        line = line.strip()

        if not line:
            continue
        if line.startswith('WEBVTT'):
            continue
        if re.match(r'^\d{2}:\d{2}:\d{2}', line):
            continue
        if '-->' in line:
            continue
        if re.match(r'^\d+$', line):
            continue
        if line.startswith('NOTE') or line.startswith('STYLE'):
            continue

        # Rimuovi tag HTML e caratteri speciali
        clean_line = re.sub(r'<[^>]+>', '', line)
        clean_line = re.sub(r'&nbsp;', ' ', clean_line)
        clean_line = re.sub(r'&amp;', '&', clean_line)
        clean_line = re.sub(r'&lt;', '<', clean_line)
        clean_line = re.sub(r'&gt;', '>', clean_line)

        if clean_line.strip():
            righe_pulite.append(clean_line)

    # Seconda passata: unisci righe che continuano la frase
    testo_finale = []

    for i, riga in enumerate(righe_pulite):
        if i == 0:
            testo_finale.append(riga)
        else:
            riga_precedente = righe_pulite[i - 1]
            # Controlla se la riga corrente inizia con minuscola
            if riga and riga[0].islower():
                # È una continuazione: unisci con spazio
                testo_finale.pop()
                riga_unita = riga_precedente + ' ' + riga
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

    # Crea nome file output
    nome_base = os.path.splitext(os.path.basename(file_vtt))[0]
    nome_base = nome_base.replace('.en', '')
    file_output = os.path.join(DESKTOP, f"{nome_base}.txt")

    # Salva file
    try:
        with open(file_output, 'w', encoding='utf-8') as f:
            f.write('\n'.join(testo_senza_dup))
        print(f"✅ File TXT creato: {os.path.basename(file_output)}")
        print(f"   Righe estratte: {len(testo_senza_dup)}")
        return file_output
    except Exception as e:
        print(f"❌ Errore salvataggio: {e}")
        return None


def elimina_file_vtt(file_vtt):
    """Elimina il file VTT originale"""
    try:
        os.remove(file_vtt)
        print(f"🗑️  File VTT eliminato: {os.path.basename(file_vtt)}")
        return True
    except Exception as e:
        print(f"⚠️  Errore eliminazione: {e}")
        return False


def main():
    print("=" * 60)
    print("🎬 TED Subtitles Downloader & Converter")
    print("=" * 60)
    print()

    # 1. Scarica sottotitoli
    if not scarica_sottotitoli():
        sys.exit(1)

    # 2. Trova file VTT
    file_vtt = trova_file_vtt()
    if not file_vtt:
        print("❌ Nessun file .vtt trovato sul Desktop")
        sys.exit(1)

    print(f"📁 Trovato: {os.path.basename(file_vtt)}")

    # 3. Converti in TXT
    file_txt = converti_in_txt(file_vtt)
    if not file_txt:
        sys.exit(1)

    # 4. Elimina VTT
    elimina_file_vtt(file_vtt)

    print()
    print("=" * 60)
    print("🎉 FATTO!")
    print(f"📄 File finale: {file_txt}")
    print("=" * 60)


if __name__ == "__main__":
    main()