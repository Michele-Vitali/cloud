import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Inserisci email e password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Se arriva qui, login riuscito! La schermata si chiuderà
      // Se arriva qui, login riuscito!
      if (mounted) {
        // Forza il rebuild della UI
        setState(() {
          _isLoading = false;
        });
        // Torna indietro
        await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore sconosciuto: $e';
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Utente non trovato. Registrati prima!';
      case 'wrong-password':
        return 'Password errata.';
      case 'invalid-email':
        return 'Email non valida.';
      case 'user-disabled':
        return 'Account disabilitato.';
      default:
        return 'Errore di login: $code';
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Inserisci email e password';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'La password deve essere almeno di 6 caratteri';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Registrazione riuscita! Chiudi la schermata
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop(); // Torna alla schermata precedente
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getRegisterErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore sconosciuto: $e';
        _isLoading = false;
      });
    }
  }

  String _getRegisterErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email già registrata. Prova il login.';
      case 'invalid-email':
        return 'Email non valida.';
      case 'weak-password':
        return 'Password troppo debole.';
      default:
        return 'Errore di registrazione: $code';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Accedi'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _register,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Registrati'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
