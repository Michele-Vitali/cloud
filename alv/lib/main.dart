import 'package:flutter/material.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'preferiti_screen.dart';
import 'profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _initialDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _initialDarkMode = doc.data()?['darkMode'] ?? false;
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) => ThemeProvider()..setDarkMode(_initialDarkMode),
      child: const MyAppContent(),
    );
  }
}

class MyAppContent extends StatelessWidget {
  const MyAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Ricerca Video',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[800],
          elevation: 2,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
        ),
        listTileTheme: ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
          tileColor: Colors.grey[800],
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.white24,
          thickness: 1,
        ),
      ),
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user != null && user.emailVerified) {
              return const SchermataRicerca();
            }
            return const LoginScreen();
          },
        ),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const SchermataRicerca(),
        '/profilo': (context) => const ProfileScreen(),
        '/preferiti': (context) => const PreferitiScreen(),
      },
    );
  }
}

class SchermataRicerca extends StatefulWidget {
  const SchermataRicerca({super.key});

  @override
  State<SchermataRicerca> createState() => _SchermataRicercaState();
}

class _SchermataRicercaState extends State<SchermataRicerca> {
  final TextEditingController _controllerTesto = TextEditingController();
  final TextEditingController _controllerDurata = TextEditingController();

  bool _isLoading = false;
  List<dynamic> _videos = [];
  String _errorMessage = '';
  bool _hasSearched = false;
  Set<String> _preferitiIds = {};

  String _formatData(String dataString) {
    try {
      final dateOnly = dataString.split('T')[0];
      final parts = dateOnly.split('-');

      if (parts.length == 3) {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);

        const months = [
          'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
          'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
        ];

        return '$day ${months[month - 1]} $year';
      }

      return 'Data non disponibile';
    } catch (e) {
      print('Errore formato data: $dataString -> $e');
      return 'Data non disponibile';
    }
  }

  Future<void> _aggiungiPreferito(Map<String, dynamic> video) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = video['title']?.toString() ?? 'video';
    final duration = video['duration']?.toString() ?? '0';
    final videoId =
        "${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$duration";

    try {
      await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .collection('preferiti')
          .doc(videoId)
          .set({
            'title': video['title'] ?? 'Titolo non disponibile',
            'speakers': video['speakers'] ?? 'Speaker non disponibile',
            'thumbnailUrl': video['images']?[0]?['url'] ?? '',
            'duration': video['duration'] ?? 0,
            'url': video['url'] ?? '',
            'savedAt': DateTime.now(),
          });

      setState(() {
        _preferitiIds.add(videoId);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aggiunto ai preferiti!')));
      }
    } catch (e) {
      print('Errore salvataggio: $e');
    }
  }

  bool _isPreferito(Map<String, dynamic> video) {
    final title = video['title']?.toString() ?? 'video';
    final duration = video['duration']?.toString() ?? '0';
    final videoId =
        "${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$duration";
    return _preferitiIds.contains(videoId);
  }

  Future<void> _rimuoviPreferito(Map<String, dynamic> video) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = video['title']?.toString() ?? 'video';
    final duration = video['duration']?.toString() ?? '0';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final videoId =
        "${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$duration$timestamp";

    try {
      await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .collection('preferiti')
          .doc(videoId)
          .delete();

      setState(() {
        _preferitiIds.remove(videoId);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rimosso dai preferiti!')));
      }
    } catch (e) {
      print('Errore rimozione: $e');
    }
  }

  String _formatDuration(int secDuration) {
    int hours = (secDuration / 3600).floor();
    int minutes = ((secDuration % 3600) / 60).floor();
    int seconds = secDuration % 60;

    String formattedDuration = "";
    if (hours > 0) {
      formattedDuration += "$hours ";
      formattedDuration += hours > 1 ? "ore " : "ora ";
    }
    if (minutes > 0) {
      formattedDuration += "$minutes ";
      formattedDuration += minutes > 1 ? "minuti " : "minuto ";
    }
    if (seconds > 0 && hours == 0) {
      formattedDuration += "$seconds ";
      formattedDuration += seconds > 1 ? "secondi" : "secondo";
    }

    return formattedDuration.trim();
  }

  Widget _buildTagContainer(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Text(
        tag[0].toUpperCase() + tag.substring(1),
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[800],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getSafeString(
    Map<String, dynamic> map,
    String key, {
    String defaultValue = '',
  }) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toString();
    if (value is bool) return value.toString();
    return defaultValue;
  }

  int _getSafeInt(
    Map<String, dynamic> map,
    String key, {
    int defaultValue = 0,
  }) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List<dynamic> _getSafeList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    String thumbnailUrl = '';
    if (video['images'] != null && video['images'].isNotEmpty) {
      thumbnailUrl = video['images'][0]['url'] ?? '';
    }

    final title = _getSafeString(video, 'title', defaultValue: 'Titolo non disponibile');
    final speakers = _getSafeString(video, 'speakers', defaultValue: 'Speaker non disponibile');
    final presenterDisplayName = _getSafeString(video, 'presenterdisplayname', defaultValue: '');
    final description = _getSafeString(video, 'description', defaultValue: 'Descrizione non disponibile');
    final publishedAt = _getSafeString(video, 'publishedat', defaultValue: '');
    final videoUrl = _getSafeString(video, 'url', defaultValue: '');
    final duration = _getSafeInt(video, 'duration', defaultValue: 0);
    final tagsList = _getSafeList(video, 'tags');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          if (videoUrl.isNotEmpty) {
            print('Apri video: $videoUrl');
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
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        width: 120,
                        height: 68,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 120,
                            height: 68,
                            color: Colors.grey[200],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
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
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            speakers.isNotEmpty ? speakers : presenterDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (publishedAt.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatData(publishedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    if (tagsList.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tagsList
                            .take(5)
                            .map((tag) => _buildTagContainer(tag.toString()))
                            .toList(),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_isPreferito(video)) {
                              _rimuoviPreferito(video);
                            } else {
                              _aggiungiPreferito(video);
                            }
                          },
                          icon: Icon(
                            _isPreferito(video)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isPreferito(video)
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callApi(String searchString) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _videos = [];
      _hasSearched = true;
    });

    try {
      // Chiediamo 10 risultati puliti
      String apiUrl =
          "https://9blumqjohk.execute-api.us-east-1.amazonaws.com/videos?q=${Uri.encodeComponent(searchString)}&limit=10";

      // Filtro Durata: passiamo i secondi al backend tramite l'URL
      String durataTesto = _controllerDurata.text.trim();
      if (durataTesto.isNotEmpty) {
        int? maxMinuti = int.tryParse(durataTesto);
        
        if (maxMinuti != null) {
          int maxSecondi = maxMinuti * 60; 
          apiUrl += "&max_duration=$maxSecondi";
        }
      }

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        setState(() {
          // L'API ha già fatto il lavoro di filtraggio!
          _videos = data['results'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              "Errore: ${response.statusCode} - ${response.reasonPhrase}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Errore di connessione: $e";
        _isLoading = false;
      });
    }
  }

  void _inviaParola() {
    String parolaInserita = _controllerTesto.text.trim();
    if (parolaInserita.isNotEmpty) {
      _callApi(parolaInserita);
    } else {
      setState(() {
        _errorMessage = "Per favore, inserisci una parola da cercare!";
        _hasSearched = false;
      });
    }
  }

  Future<void> _caricaPreferiti() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .collection('preferiti')
          .get();

      setState(() {
        _preferitiIds = doc.docs.map((d) => d.id).toSet();
      });
    } catch (e) {
      print('Errore caricamento preferiti: $e');
    }
  }

  @override
  void dispose() {
    _controllerTesto.dispose();
    _controllerDurata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _caricaPreferiti();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('FOCUS-TED'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profilo');
            },
            tooltip: 'Profilo',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Logout',
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.pushNamed(context, '/preferiti');
            },
            tooltip: 'Preferiti',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di ricerca + Filtro Durata
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _controllerTesto,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Cerca video...',
                          hintText: 'Es. Species',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _inviaParola(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _controllerDurata,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Max min.',
                          hintText: 'Es. 15',
                          prefixIcon: Icon(Icons.timer, size: 20),
                        ),
                        onSubmitted: (_) => _inviaParola(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _inviaParola,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Cerca Video',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Contenuto principale
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento video in corso...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Digita una parola per cercare i video',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nessun video trovato',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        return _buildVideoCard(_videos[index]);
      },
    );
  }
}