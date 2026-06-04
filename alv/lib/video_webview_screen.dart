import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoWebViewScreen extends StatefulWidget {
  final String videoId;

  const VideoWebViewScreen({super.key, required this.videoId});

  @override
  State<VideoWebViewScreen> createState() => _VideoWebViewScreenState();
}

class _VideoWebViewScreenState extends State<VideoWebViewScreen> {
  // ---------- STATO ----------
  WebViewController? controller;
  bool isLoadingWebView = true;   // indica se la WebView sta caricando
  String errorMessage = "";
  Map<String, dynamic>? videoData;

  // trascrizione
  bool showTranscript = false;

  // preferiti
  bool isFavorite = false;
  bool isCheckingFavorite = true;

  // raccomandazioni personalizzate
  List<dynamic>? recommendedVideos;
  bool isLoadingRecommendations = false;

  // ---------- CICLO DI VITA ----------
  @override
  void initState() {
    super.initState();
    _caricaVideo();
    _caricaRaccomandazioni();   // parte in background
  }

  // ======================== 1. CARICAMENTO DATI VIDEO ========================
  Future<void> _caricaVideo() async {
    try {
      // 1a. Chiamo l'API per avere i dati completi del video
      final response = await http.get(
        Uri.parse(
          "https://uihbu3x21c.execute-api.us-east-1.amazonaws.com/video?id=${widget.videoId}",
        ),
      );

      if (response.statusCode != 200) {
        throw Exception("Errore server ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      // 1b. Preparo l'URL per la WebView (embed)
      final url = data["url"] ?? "";
      final embedUrl = url.replaceFirst(
        "https://www.ted.com/talks/",
        "https://embed.ted.com/talks/",
      );

      // 1c. Creo il controller della WebView (senza cascade operator per chiarezza)
      final webController = WebViewController();
      webController.setJavaScriptMode(JavaScriptMode.unrestricted);

      // 1d. Imposto il delegate di navigazione
      webController.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoadingWebView = true;
              errorMessage = "";
            });
          },
          onPageFinished: (url) {
            setState(() {
              isLoadingWebView = false;
            });
          },
          onWebResourceError: (webError) {
            // mostro errore solo se la pagina non era ancora partita
            if (isLoadingWebView) {
              setState(() {
                errorMessage = "Errore caricamento video";
                isLoadingWebView = false;
              });
            }
          },
          onNavigationRequest: (request) {
            // consento solo navigazioni verso TED
            if (request.url.contains('embed.ted.com') ||
                request.url.contains('ted.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

      // 1e. Carico l'URL
      webController.loadRequest(Uri.parse(embedUrl));

      // 1f. Aggiorno lo stato
      setState(() {
        videoData = data;
        controller = webController;
        isLoadingWebView = true;
        errorMessage = "";
      });

      // 1g. Controllo se il video è già nei preferiti
      _verificaPreferito();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingWebView = false;
      });
    }
  }

  // ======================== 2. PREFERITI ========================
  Future<void> _verificaPreferito() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isCheckingFavorite = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .collection('preferiti')
          .doc(widget.videoId)
          .get();

      setState(() {
        isFavorite = doc.exists;
        isCheckingFavorite = false;
      });
    } catch (e) {
      setState(() {
        isCheckingFavorite = false;
      });
    }
  }

  Future<void> _togglePreferito() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (isFavorite) {
        // rimuovo dai preferiti
        await FirebaseFirestore.instance
            .collection('utenti')
            .doc(user.uid)
            .collection('preferiti')
            .doc(widget.videoId)
            .delete();

        setState(() {
          isFavorite = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rimosso dai preferiti!')),
          );
        }
      } else {
        // aggiungo ai preferiti
        await FirebaseFirestore.instance
            .collection('utenti')
            .doc(user.uid)
            .collection('preferiti')
            .doc(widget.videoId)
            .set({
              'talk_title': videoData?['talk_title'] ?? '',
              'speakers': videoData?['speakers'] ?? '',
              'thumbnailUrl': videoData?['images']?[0] ?? '',
              'duration': videoData?['duration'] ?? 0,
              'url': videoData?['url'] ?? '',
              'addedAt': DateTime.now(),
            });

        setState(() {
          isFavorite = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aggiunto ai preferiti!')),
          );
        }
      }
    } catch (e) {
      print('Errore preferiti: $e');
    }
  }

  // ======================== 3. RACCOMANDAZIONI PERSONALIZZATE ========================
  Future<void> _caricaRaccomandazioni() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoadingRecommendations = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://vguebl4x94.execute-api.us-east-1.amazonaws.com/recommendations'
          '?userId=${user.uid}'
          '&currentVideoId=${widget.videoId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          recommendedVideos = data['recommended'] ?? [];
          isLoadingRecommendations = false;
        });
      } else {
        throw Exception('Errore API ${response.statusCode}');
      }
    } catch (e) {
      print('Errore raccomandazioni: $e');
      setState(() {
        recommendedVideos = [];   // così non riprovo più
        isLoadingRecommendations = false;
      });
    }
  }

  // ======================== 4. FORMATTAZIONE ========================
  String _formattaDurata(int secondi) {
    final min = secondi ~/ 60;
    final sec = secondi % 60;
    return "$min:${sec.toString().padLeft(2, "0")}";
  }

  String _formattaData(String dataString) {
    try {
      final date = DateTime.parse(dataString);
      const mesi = [
        'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
        'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
      ];
      return '${date.day} ${mesi[date.month - 1]} ${date.year}';
    } catch (e) {
      return dataString;
    }
  }

  // ======================== 5. WIDGET RIUTILIZZABILI ========================
  Widget _anteprimaImmagine(String url) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 120,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconaPlaceholder(),
        ),
      );
    } else {
      return _iconaPlaceholder();
    }
  }

  Widget _iconaPlaceholder() {
    return Container(
      width: 120,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.video_library, color: Colors.grey, size: 32),
    );
  }

  // Card per i video correlati statici
  Widget _cardVideoCorrelato(Map<String, dynamic> video) {
    final imageUrl = video['related_image_url'] ?? '';
    final title = video['title'] ?? 'Titolo non disponibile';
    final presenter = video['presenterDisplayName'] ?? '';
    final duration = int.tryParse(video['duration']?.toString() ?? '0') ?? 0;
    final relatedId = video['related_id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (relatedId.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VideoWebViewScreen(videoId: relatedId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anteprimaImmagine(imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (presenter.isNotEmpty)
                      Text(
                        presenter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formattaDurata(duration),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Card per i consigliati (API personalizzata)
  Widget _cardVideoConsigliato(Map<String, dynamic> video) {
    // l'API restituisce immagini come array di URL
    final imageUrl = (video['images'] != null && video['images'].isNotEmpty)
        ? video['images'][0]
        : '';
    final title = video['talk_title'] ?? 'Titolo non disponibile';
    final presenter = video['speakers'] ?? '';
    final duration = video['duration'] is int ? video['duration'] as int : 0;
    final recId = video['_id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (recId.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VideoWebViewScreen(videoId: recId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anteprimaImmagine(imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (presenter.isNotEmpty)
                      Text(
                        presenter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formattaDurata(duration),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ======================== 6. SCHERMATA PRINCIPALE ========================
  @override
  Widget build(BuildContext context) {
    // ---------- 6a. Se c'è un errore, mostro la schermata di errore ----------
    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Video")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      errorMessage = "";
                      isLoadingWebView = true;
                    });
                    _caricaVideo();
                  },
                  child: const Text("Riprova"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---------- 6b. Se i dati non sono ancora pronti, mostro un caricamento ----------
    if (videoData == null || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ---------- 6c. Estraggo i dati dal JSON ----------
    final title = videoData!["talk_title"] ?? "";
    final speaker = videoData!["speakers"] ?? "";
    final description = videoData!["description"] ?? "";
    final duration = videoData!["duration"] ?? 0;
    final published = videoData!["publishedAt"] ?? "";
    final tags = videoData!["tags"] ?? [];
    final transcript = videoData!["transcript_text"] ?? "";
    final relatedVideos = videoData!["related_videos"] ?? [];

    // ---------- 6d. Costruisco la pagina ----------
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!isCheckingFavorite)
            IconButton(
              onPressed: _togglePreferito,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              tooltip: isFavorite ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- PLAYER ----
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: WebViewWidget(controller: controller!),
                ),
                if (isLoadingWebView)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),

            // ---- DETTAGLI ----
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titolo
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Pulsante trascrizione
                  if (transcript.isNotEmpty)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              showTranscript = !showTranscript;
                            });
                          },
                          icon: Icon(showTranscript ? Icons.visibility_off : Icons.visibility),
                          label: Text(showTranscript ? "Nascondi trascrizione" : "Mostra trascrizione"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (showTranscript) ...[
                          const SizedBox(height: 10),
                          Container(
                            height: 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Text(transcript, style: const TextStyle(fontSize: 14, height: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),

                  const SizedBox(height: 10),
                  // Speaker
                  Text(speaker, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  // Durata e data
                  Text("Durata: ${_formattaDurata(duration)}"),
                  Text("Pubblicato: ${_formattaData(published)}"),
                  const SizedBox(height: 20),
                  // Descrizione
                  const Text("Descrizione", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description),
                  const SizedBox(height: 20),
                  // Tag
                  if (tags.isNotEmpty) ...[
                    const Text("Tag", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: tags.map<Widget>((tag) {
                        return Chip(label: Text(tag));
                      }).toList(),
                    ),
                  ],

                  // ---- VIDEO CORRELATI STATICI ----
                  if (relatedVideos.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text("Video correlati", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...relatedVideos.map<Widget>((video) => _cardVideoCorrelato(video)).toList(),
                  ],

                  // ---- CONSIGLIATI PER TE (DINAMICI) ----
                  if (recommendedVideos != null && recommendedVideos!.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text("Consigliati per te", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...recommendedVideos!.map<Widget>((video) => _cardVideoConsigliato(video)).toList(),
                  ] else if (isLoadingRecommendations) ...[
                    const SizedBox(height: 30),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}