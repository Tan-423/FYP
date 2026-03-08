import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'otp_verification_page.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _sendOtpEmail(String toEmail, String otpCode) async {
    const String serviceId = 'service_jxj3xvx';
    const String templateId = 'template_pq1fd0s';
    const String publicKey = 'gHPo3cztD1hr3GgOD';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': toEmail,
            'reply_to': toEmail,
            'passcode': otpCode,
            'time': '15 minutes',
          },
        }),
      );

      if (response.statusCode == 200) {
        return "SUCCESS";
      } else {
        return "EmailJS Error: ${response.body}";
      }
    } catch (e) {
      return "Network Error: $e";
    }
  }

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Block AuthGate from jumping to MainShell during the OTP flow.
    otpInProgress = true;

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Credentials verified. Sign out so Firebase session is clean
        // until OTP is confirmed. AuthGate won't redirect because
        // otpInProgress is true.
        await FirebaseAuth.instance.signOut();

        String generatedOtp = (Random().nextInt(900000) + 100000).toString();
        String emailResult = await _sendOtpEmail(email, generatedOtp);

        if (mounted) {
          if (emailResult == "SUCCESS") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP sent to your email address!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationPage(
                  generatedOtp: generatedOtp,
                  email: email,
                  password: password,
                ),
              ),
            );
          } else {
            // Email failed — clear the flag so login page works normally
            otpInProgress = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(emailResult),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      otpInProgress = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flight_takeoff,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'TRAVEL',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PLAN LESS, TRAVEL MORE',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _emailController,
                icon: Icons.email_outlined,
                hint: "Email",
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                icon: Icons.lock_outline,
                hint: "Password",
                isPassword: true,
                isDark: isDark,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            'LOGIN',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account yet? ",
                    style: GoogleFonts.montserrat(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  InkWell(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        ),
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Text(
                        "Sign up",
                        style: GoogleFonts.montserrat(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    required bool isDark,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed:
                        () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                  )
                  : null,
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
