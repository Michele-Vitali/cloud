import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ricerca Video',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SchermataRicerca(),
    );
  }
}

class SchermataRicerca extends StatefulWidget {
  const SchermataRicerca({super.key});

  @override
  State<SchermataRicerca> createState() => _SchermataRicercaState();
}

class _SchermataRicercaState extends State<SchermataRicerca> {
  // Questo controller ci permette di leggere cosa scrive l'utente nella casella
  final TextEditingController _controllerTesto = TextEditingController();
  
  // Variabile per mostrare a schermo cosa sta succedendo
  String _messaggioRisultato = "Digita una parola per cercare i video";

  // Funzione che viene chiamata quando premi il bottone
  void _inviaParola() {
    String parolaInserita = _controllerTesto.text;

    if (parolaInserita.isNotEmpty) {
      setState(() {
        _messaggioRisultato = "Hai scritto: '$parolaInserita'.\n\nIn attesa dell'API Gateway di Vitali...";
      });

      // TODO: Qui in futuro aggiungeremo la chiamata HTTP all'API di Vitali
      // per passargli 'parolaInserita' e ricevere i titoli dei video.
    } else {
      setState(() {
        _messaggioRisultato = "Per favore, inserisci una parola!";
      });
    }
  }

  // È buona norma "pulire" il controller quando la schermata viene chiusa
  @override
  void dispose() {
    _controllerTesto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App di ALV (Algeri Locatelli, Vitali)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // La casella di testo
            TextField(
              controller: _controllerTesto,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Cerca parola chiave',
                hintText: 'Es: Flutter, MongoDB, Lambda...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20), // Spazio tra casella e bottone
            
            // Il bottone per inviare
            ElevatedButton(
              onPressed: _inviaParola,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Cerca Video', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 40), // Spazio tra bottone e risultato
            
            // Testo che mostra il risultato o lo stato attuale
            Text(
              _messaggioRisultato,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}