import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'preferiti_screen.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _salvaCronologia = true;
  bool _notifichePush = true;
  String _linguaSelezionata = 'Italiano';

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('utenti').doc(user.uid).set({
      'darkMode': _isDarkMode,
      'salvaCronologia': _salvaCronologia,
      'notifichePush': _notifichePush,
      'lingua': _linguaSelezionata,
    }, SetOptions(merge: true));
  }

  Future<void> _loadSettings() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection('utenti')
      .doc(user.uid)
      .get();

  if (doc.exists) {
    setState(() {
      // SOLO queste impostazioni - NIENTE tema
      _salvaCronologia = doc.data()?['salvaCronologia'] ?? true;
      _notifichePush = doc.data()?['notifichePush'] ?? true;
      _linguaSelezionata = doc.data()?['lingua'] ?? 'Italiano';
    });
  }
}

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Questo carica le altre impostazioni MA NON il tema
  }

  Future<void> _changePassword() async {
    final email = user?.email;
    if (email == null) return;

    setState(() => _isLoading = true);

    try {
      // Invia email per il reset della password
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email per il reset della password inviata! Controlla la tua posta.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    // Mostra un dialogo di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Sei sicuro? Questa operazione è irreversibile.\n\nTutti i tuoi dati verranno cancellati permanentemente:\n• Preferiti\n• Impostazioni\n• Account',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utente non loggato');

      // 1. ELIMINA TUTTI I PREFERITI DELL'UTENTE
      final preferitiSnapshot = await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .collection('preferiti')
          .get();

      // Elimina ogni documento della sub-collection preferiti
      for (var doc in preferitiSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. ELIMINA IL DOCUMENTO PRINCIPALE DELL'UTENTE (se esiste)
      await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .delete();

      // 3. ELIMINA L'ACCOUNT FIREBASE AUTH
      await user.delete();

      // 4. TORNA ALLA SCHERMATA DI LOGIN
      if (mounted) {
        // Svuota la navigazione e torna al login
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il mio profilo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Sezione account (esistente)
                _buildAccountSection(),

                // Sezione contenuti (esistente)
                _buildContentSection(),

                // 👇 NUOVA SEZIONE PREFERENZE
                _buildPreferencesSection(),

                // Sezione sicurezza (esistente)
                _buildSecuritySection(),

                // Versione app (esistente)
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'FOCUS-TED v1.0',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildAccountSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'Non disponibile'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contenuti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: const Text('I miei preferiti'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/preferiti');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferenze',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Tema scuro/chiaro
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                title: const Text('Tema scuro'),
                subtitle: const Text('Attiva la modalità scura'),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.setDarkMode(value);
                  _saveSettings();
                },
                secondary: const Icon(Icons.dark_mode),
              );
            },
          ),

          const Divider(),

          // Cronologia ricerche
          SwitchListTile(
            title: const Text('Salva cronologia ricerche'),
            subtitle: const Text('Memorizza le tue ricerche'),
            value: _salvaCronologia,
            onChanged: (value) {
              setState(() {
                _salvaCronologia = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.history),
          ),

          const Divider(),

          // Notifiche push
          SwitchListTile(
            title: const Text('Notifiche push'),
            subtitle: const Text('Ricevi suggerimenti di nuovi TED Talk'),
            value: _notifichePush,
            onChanged: (value) {
              setState(() {
                _notifichePush = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.notifications),
          ),

          const Divider(),

          // Lingua
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Lingua'),
            subtitle: Text(_linguaSelezionata),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showLanguageDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sicurezza',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Cambia password'),
            subtitle: const Text('Riceverai un link via email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Elimina account',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Questa operazione è irreversibile'),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona lingua'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Italiano'),
              leading: Radio<String>(
                value: 'Italiano',
                groupValue: _linguaSelezionata,
                onChanged: (value) {
                  setState(() {
                    _linguaSelezionata = value!;
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'English',
                groupValue: _linguaSelezionata,
                onChanged: (value) {
                  setState(() {
                    _linguaSelezionata = value!;
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
