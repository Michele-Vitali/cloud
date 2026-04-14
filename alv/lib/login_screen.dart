import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  String _successMessage = '';

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
      _successMessage = '';
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      // Controlla se l'email è verificata
      if (updatedUser == null || !updatedUser.emailVerified) {
        // Se non è verificata, esci e mostra messaggio di errore
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          setState(() {
            _errorMessage =
                '❌ Email non verificata!\n\nControlla la tua posta e clicca sul link di verifica ricevuto al momento della registrazione.\n\nSe non trovi l\'email, controlla nella cartella Spam.';
            _isLoading = false;
          });
        }
        return; // Esce senza chiudere la schermata
      }

      // Se arriva qui, email verificata → login OK
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.code);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore sconosciuto: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      // Crea una nuova istanza di GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Forza il logout da Google per chiedere sempre la selezione dell'account
      await googleSignIn.signOut();

      // Per Web usa signInWithPopup
      if (const bool.fromEnvironment('dart.library.html')) {
        // Siamo sul Web
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // Per il web, forza la selezione dell'account
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Per mobile (Android/iOS)
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore con Google Sign-In: $e';
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
        _successMessage = '';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'La password deve essere almeno di 6 caratteri';
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      // 1) Crea l'utente
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2) Invia email di verifica
      await userCredential.user?.sendEmailVerification();

      // 3) Logout immediato per evitare accesso senza verifica
      await FirebaseAuth.instance.signOut();

      // 4) Aggiorna UI rimanendo in questa schermata
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
          _successMessage =
              '✅ Registrazione completata!\n\nTi abbiamo inviato una email di verifica a:\n$email\n\nControlla la posta, clicca sul link di verifica e poi effettua l’accesso.';
        });

        // 5) Svuota solo la password (meglio lasciare l’email)
        _passwordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getRegisterErrorMessage(e.code);
          _successMessage = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore sconosciuto: $e';
          _successMessage = '';
          _isLoading = false;
        });
      }
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

            if (_successMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _successMessage,
                  style: const TextStyle(color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Accedi con Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Separatore
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('oppure'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

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
