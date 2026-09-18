import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =========================
  // CREATE ACCOUNT
  // =========================
  Future<void> createAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // -------------------------
    // VALIDATION
    // -------------------------

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage(
        "Please fill all fields",
        Colors.red,
      );
      return;
    }

    if (password != confirmPassword) {
      showMessage(
        "Passwords do not match",
        Colors.red,
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        "Password must be at least 6 characters",
        Colors.red,
      );
      return;
    }

    if (phone.length < 10) {
      showMessage(
        "Please enter a valid phone number",
        Colors.red,
      );
      return;
    }

    // -------------------------
    // START LOADING
    // -------------------------

    setState(() {
      isLoading = true;
    });

    try {
      // =========================
      // STEP 1
      // FIREBASE AUTHENTICATION
      // =========================

      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get created user's UID
      final User? user = userCredential.user;

      if (user == null) {
        showMessage(
          "Account creation failed",
          Colors.red,
        );
        return;
      }

      // =========================
      // STEP 2
      // SAVE USER DATA
      // FIRESTORE
      // =========================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // =========================
      // SUCCESS
      // =========================

      if (!mounted) return;

      showMessage(
        "Account created successfully!",
        Colors.green,
      );

      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return;

      // Go to Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }

    // =========================
    // FIREBASE AUTH ERROR
    // =========================

    on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = "This email is already registered";
          break;

        case 'invalid-email':
          message = "Please enter a valid email";
          break;

        case 'weak-password':
          message = "Password is too weak";
          break;

        case 'network-request-failed':
          message = "Please check your internet connection";
          break;

        default:
          message = e.message ?? "Account creation failed";
      }

      if (!mounted) return;

      showMessage(
        message,
        Colors.red,
      );
    }

    // =========================
    // FIRESTORE / OTHER ERROR
    // =========================

    catch (e) {
      if (!mounted) return;

      showMessage(
        "Something went wrong. Please try again.",
        Colors.red,
      );
    }

    // =========================
    // STOP LOADING
    // =========================

    finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================
  // SHOW MESSAGE
  // =========================

  void showMessage(
      String message,
      Color color,
      ) {
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
        title: const Text(
          "Create Account",
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 20),

            // -------------------------
            // PROFILE ICON
            // -------------------------

            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.person_add,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // TITLE
            // -------------------------

            const Text(
              "Create Your Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // -------------------------
            // NAME
            // -------------------------

            TextField(
              controller: nameController,

              decoration: InputDecoration(
                labelText: "Full Name",
                hintText: "Enter your full name",

                prefixIcon: const Icon(
                  Icons.person,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // EMAIL
            // -------------------------

            TextField(
              controller: emailController,

              keyboardType:
              TextInputType.emailAddress,

              decoration: InputDecoration(
                labelText: "Email",
                hintText: "Enter your email",

                prefixIcon: const Icon(
                  Icons.email,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // PHONE
            // -------------------------

            TextField(
              controller: phoneController,

              keyboardType:
              TextInputType.phone,

              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: "Enter your phone number",

                prefixIcon: const Icon(
                  Icons.phone,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // PASSWORD
            // -------------------------

            TextField(
              controller: passwordController,

              obscureText: obscurePassword,

              decoration: InputDecoration(
                labelText: "Password",
                hintText: "Enter your password",

                prefixIcon: const Icon(
                  Icons.lock,
                ),

                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {
                    setState(() {
                      obscurePassword =
                      !obscurePassword;
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // CONFIRM PASSWORD
            // -------------------------

            TextField(
              controller:
              confirmPasswordController,

              obscureText:
              obscureConfirmPassword,

              decoration: InputDecoration(
                labelText: "Confirm Password",
                hintText:
                "Re-enter your password",

                prefixIcon: const Icon(
                  Icons.lock_outline,
                ),

                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword =
                      !obscureConfirmPassword;
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // -------------------------
            // CREATE ACCOUNT BUTTON
            // -------------------------

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.deepPurple,

                  foregroundColor:
                  Colors.white,

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(15),
                  ),
                ),

                onPressed:
                isLoading
                    ? null
                    : createAccount,

                child: isLoading
                    ? const SizedBox(
                  width: 25,
                  height: 25,

                  child:
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text(
                  "Create Account",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            // LOGIN
            // -------------------------

            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                    builder: (context) =>
                    const LoginScreen(),
                  ),
                );
              },

              child: const Text(
                "Already have an account? Login",
              ),
            ),
          ],
        ),
      ),
    );
  }
}