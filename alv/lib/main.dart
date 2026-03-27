import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

      /*
      * Esistono 3 type per ora:
      * - all, una ricerca della stringa ra un po tutti i campi del video
      * - speaker, cerca la stringa nell'attributo speaker
      * - title, cerca la stringa nell'attributo title
      */
      String type = "all"; 
      String parameter = parolaInserita;
      final api_url = "https://9ax7s2e799.execute-api.us-east-1.amazonaws.com/dev/search/${type}?q=${parameter}&limit={5}";
    
      final response = http.get(Uri.parse(api_url));

      if(response. == 200){
        final data = json.decode(response.body);
        final res = data['body'];

        for(var i=0; i < res.length; i++){
          print("[${i+1}] Titolo: ${res['title']}");
        }
      }
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