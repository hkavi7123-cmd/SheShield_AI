import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================
  // FIREBASE LOGIN
  // =========================
  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Empty field validation
    if (email.isEmpty && password.isEmpty) {
      showMessage(
        "Please enter Email and Password",
        Colors.red,
      );
      return;
    }

    if (email.isEmpty) {
      showMessage(
        "Please enter your Email",
        Colors.red,
      );
      return;
    }

    if (password.isEmpty) {
      showMessage(
        "Please enter your Password",
        Colors.red,
      );
      return;
    }

    // Start loading
    setState(() {
      isLoading = true;
    });

    try {
      // Firebase Authentication
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      showMessage(
        "Login Successful",
        Colors.green,
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      // Go to Home Screen and clear navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = "No account found with this email";
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = "Incorrect email or password";
          break;

        case 'invalid-email':
          message = "Please enter a valid email";
          break;

        case 'network-request-failed':
          message = "Please check your internet connection";
          break;

        case 'too-many-requests':
          message = "Too many login attempts. Try again later";
          break;

        case 'user-disabled':
          message = "This account has been disabled";
          break;

        default:
          message = e.message ?? "Login failed";
      }

      if (!mounted) return;

      showMessage(
        message,
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "Something went wrong",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================
  // FORGOT PASSWORD
  // =========================
  Future<void> forgotPassword() async {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        "Please enter your email first",
        Colors.red,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      showMessage(
        "Password reset link sent to your email",
        Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = "Please enter a valid email";
          break;

        case 'user-not-found':
          message = "No account found with this email";
          break;

        case 'network-request-failed':
          message = "Please check your internet connection";
          break;

        default:
          message = e.message ?? "Unable to send reset email";
      }

      if (!mounted) return;

      showMessage(
        message,
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "Something went wrong",
        Colors.red,
      );
    }
  }

  // =========================
  // SNACKBAR MESSAGE
  // =========================
  void showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "SheShield AI",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            const SizedBox(height: 40),

            // Shield Icon
            const CircleAvatar(
              radius: 55,
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.shield,
                color: Colors.white,
                size: 60,
              ),
            ),

            const SizedBox(height: 20),

            // Welcome
            const Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Login to continue to SheShield AI",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 35),

            // Email
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,

              decoration: InputDecoration(
                labelText: "Email",
                hintText: "Enter your email",

                prefixIcon: const Icon(
                  Icons.email,
                  color: Colors.deepPurple,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Colors.deepPurple,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Password
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,

              decoration: InputDecoration(
                labelText: "Password",
                hintText: "Enter your password",

                prefixIcon: const Icon(
                  Icons.lock,
                  color: Colors.deepPurple,
                ),

                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Colors.deepPurple,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,

              child: TextButton(
                onPressed: forgotPassword,

                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                onPressed: isLoading ? null : login,

                child: isLoading
                    ? const SizedBox(
                  width: 25,
                  height: 25,

                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text(
                  "Login",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Create Account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (context) =>
                        const SignupScreen(),
                      ),
                    );
                  },

                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}