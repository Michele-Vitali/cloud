**numero righe**
details.csv            7384
final_list.csv         7969
images.csv             14196
related_videos.csv     37727
tags.csv               49220

**colonne per file**
*details.csv (metadati principali)*

  -  id: Identificativo univoco del video (es: 567505)
  -  slug: Versione URL-friendly del titolo per i link TED (es: ben_proudfoot_the_true_story_of_the_iconic_tagline_because_i_m_worth_it_the_final_copy_of_ilon_specht)
  -  interalId: ID interno numerico del talk (typo nel file, dovrebbe essere internalId) (es: 147074)
  -  description: Descrizione completa e dettagliata del contenuto del video
  -  duration: Durata del video in secondi (es: 1059)
  -  socialDescription: Versione breve della descrizione per condivisioni social
  -  presenterDisplayName: Nome dello speaker o del canale che ha pubblicato il talk (es: Ben Proudfoot)
  -  publishedAt: Data e ora di pubblicazione in formato ISO 8601 (es: 2025-03-07T13:49:56Z)

*final_list.csv (dati essenziali)*

   - id: ID univoco del video (corrisponde a details)
   - slug: URL-friendly del titolo (duplicato da details per comodità)
   - speakers: Nome dello speaker (ripetuto, simile a presenterDisplayName)
   - title: Titolo formattato del talk con spazi e punteggiatura corretti
   - url: Link completo alla pagina TED del video (https://www.ted.com/talks/...)

*images.csv (immagini/thumbnail)*

   - id: ID del video a cui appartiene l'immagine
   - slug: Slug del video per referenza
   - url: URL diretto all'immagine su S3 (formati disponibili: 16x9, 2x1, 4x3, ecc.)

*related_videos.csv (video correlati)*

    - id: ID del video principale (quello di cui stiamo leggendo i correlati)
    - internalId: ID interno del video principale
    - related_id: ID del video correlato suggerito
    - slug: Slug del video correlato
    - title: Titolo del video suggerito
    - duration: Durata in secondi del video correlato
    - viewedCount: Numero di visualizzazioni del video correlato
    - presenterDisplayName: Speaker del video correlato

*tags.csv (categorie/etichette)*

   - id: ID del video taggato
   - slug: Slug del video per referenza
   - internalId: ID interno del video
   - tag: Singola parola chiave/categoria (es: "culture", "AI", "science") - ogni video ha multipli tag su righe diverse

**Come è fatto il nostro MongoDB**
Il database ted_video_db_3 contiene la collection videos con ~7100 documenti JSON, uno per ogni video TED. Ogni documento include i metadati di base (titolo, descrizione, speaker, durata, url) più tre array nidificati: tags (lista di categorie), images (oggetti con url delle thumbnail), e related_videos (oggetti con dati dei video correlati).
Lo schema è denormalizzato: abbiamo aggregato le 5 tabelle relazionali (details, final_list, tags, images, related_videos) in un singolo documento per video, evitando il cartesian product dei join multipli. Questo riduce lo storage da oltre 500MB (con duplicazioni) a circa 3MB, rispettando il limite del piano free di MongoDB Atlas (512MB) e ottimizzando le query per lettura.
I dati vengono aggiornati sovrascrivendo l'intera collection tramite AWS Glue job PySpark, garantendo coerenza completa ad ogni run.
