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
  WebViewController? controller;
  bool isLoading = true;
  String error = "";
  Map<String, dynamic>? videoData;
  bool showTranscript = false;
  bool isFavorite = false;
  bool isCheckingFavorite = true;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _checkIfFavorite() async {
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

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (isFavorite) {
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

  Future<void> _loadVideo() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://uihbu3x21c.execute-api.us-east-1.amazonaws.com/video?id=${widget.videoId}",
        ),
      );

      if (response.statusCode != 200) {
        throw Exception("Errore server ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      final url = data["url"] ?? "";

      final embedUrl = url.replaceFirst(
        "https://www.ted.com/talks/",
        "https://embed.ted.com/talks/",
      );

      final newController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              setState(() {
                isLoading = true;
                error = "";
              });
            },
            onPageFinished: (url) {
              setState(() {
                isLoading = false;
              });
            },
            onWebResourceError: (webError) {
              if (isLoading) {
                setState(() {
                  error = "Errore caricamento video";
                  isLoading = false;
                });
              }
            },
            onNavigationRequest: (request) {
              if (request.url.contains('embed.ted.com') ||
                  request.url.contains('ted.com')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(Uri.parse(embedUrl));

      setState(() {
        videoData = data;
        controller = newController;
        isLoading = true;
        error = "";
      });

      _checkIfFavorite();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String formatDuration(int sec) {
    final min = sec ~/ 60;
    final seconds = sec % 60;
    return "$min:${seconds.toString().padLeft(2, "0")}";
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'Gennaio',
        'Febbraio',
        'Marzo',
        'Aprile',
        'Maggio',
        'Giugno',
        'Luglio',
        'Agosto',
        'Settembre',
        'Ottobre',
        'Novembre',
        'Dicembre',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildRelatedVideoCard(Map<String, dynamic> video) {
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 120,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 120,
                          height: 68,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.video_library,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      )
                    : Container(
                        width: 120,
                        height: 68,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.video_library,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                          formatDuration(duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) {
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
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      error = "";
                      isLoading = true;
                    });
                    _loadVideo();
                  },
                  child: const Text("Riprova"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (videoData == null || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = videoData!["talk_title"] ?? "";
    final speaker = videoData!["speakers"] ?? "";
    final description = videoData!["description"] ?? "";
    final duration = videoData!["duration"] ?? 0;
    final published = videoData!["publishedAt"] ?? "";
    final tags = videoData!["tags"] ?? [];
    final transcript = videoData!["transcript_text"] ?? "";
    final relatedVideos = videoData!["related_videos"] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!isCheckingFavorite)
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              tooltip: isFavorite
                  ? 'Rimuovi dai preferiti'
                  : 'Aggiungi ai preferiti',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player video
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: WebViewWidget(controller: controller!),
                ),
                if (isLoading)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),

            // Dettagli video
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                          icon: Icon(
                            showTranscript
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          label: Text(
                            showTranscript
                                ? "Nascondi trascrizione"
                                : "Mostra trascrizione",
                          ),
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
                              child: Text(
                                transcript,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),

                  const SizedBox(height: 10),
                  Text(
                    speaker,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Durata: ${formatDuration(duration)}"),
                  Text("Pubblicato: ${formatDate(published)}"),
                  const SizedBox(height: 20),
                  const Text(
                    "Descrizione",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                  const SizedBox(height: 20),
                  if (tags.isNotEmpty) ...[
                    const Text(
                      "Tag",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: tags.map<Widget>((tag) {
                        return Chip(label: Text(tag));
                      }).toList(),
                    ),
                  ],

                  // Video correlati
                  if (relatedVideos.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Text(
                      "Video correlati",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...relatedVideos.map<Widget>((video) {
                      return _buildRelatedVideoCard(video);
                    }).toList(),
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
