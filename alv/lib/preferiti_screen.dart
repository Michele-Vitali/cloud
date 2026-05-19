import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_webview_screen.dart';

class PreferitiScreen extends StatelessWidget {
  const PreferitiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Devi fare il login')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('I tuoi preferiti'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('utenti')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nessun preferito ancora'),
                  Text('Aggiungi video cliccando sul cuore ❤️'),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> preferiti = data['preferiti'] ?? [];

          if (preferiti.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nessun preferito ancora'),
                  Text('Aggiungi video cliccando sul cuore ❤️'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: preferiti.length,
            itemBuilder: (context, index) {
              final video = preferiti[index] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading:
                      video['thumbnailUrl'] != null &&
                              video['thumbnailUrl'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                video['thumbnailUrl'].toString(),
                                width: 60,
                                height: 45,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.video_library),
                              ),
                            )
                          : const Icon(Icons.video_library, size: 45),
                  title: Text(
                    video['talk_title'] ?? 'Titolo non disponibile',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(video['speakers'] ?? 'Speaker non disponibile'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // Rimuovi dall'array
                      final docRef = FirebaseFirestore.instance
                          .collection('utenti')
                          .doc(user.uid);
                      
                      await docRef.update({
                        'preferiti': FieldValue.arrayRemove([video])
                      });
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rimosso dai preferiti')),
                        );
                      }
                    },
                  ),
                  onTap: () {
                    final videoUrl = video['url'] ?? '';
                    final title = video['talk_title'] ?? 'Video';

                    if (videoUrl.toString().isNotEmpty) {
                      final embedUrl = videoUrl.toString().replaceFirst(
                        "https://www.ted.com/talks/",
                        "https://embed.ted.com/talks/",
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoWebViewScreen(url: embedUrl, title: title),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}