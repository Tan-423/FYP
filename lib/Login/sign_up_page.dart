import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please agree to the Terms of Service')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        await userCredential.user!.updateDisplayName(_nameController.text.trim());
        await userCredential.user!.sendEmailVerification();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'fullName': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'uid': userCredential.user!.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'isVerified': false,
            });

        await FirebaseAuth.instance.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Please verify your email before logging in.',
              ),
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Registration failed")),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        "Join the Adventure",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign up to start planning your next trip.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildInputField(
                        controller: _nameController,
                        label: "Full Name",
                        hint: "John Doe",
                        isDark: isDark,
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      _buildInputField(
                        controller: _emailController,
                        label: "Email",
                        hint: "name@example.com",
                        inputType: TextInputType.emailAddress,
                        isDark: isDark,
                        validator:
                            (v) => !v!.contains("@") ? "Invalid email" : null,
                      ),
                      _buildInputField(
                        controller: _phoneController,
                        label: "Phone",
                        hint: "+60 12-345 6789",
                        inputType: TextInputType.phone,
                        isDark: isDark,
                        validator: (v) => v!.length < 8 ? "Too short" : null,
                      ),
                      _buildInputField(
                        controller: _passwordController,
                        label: "Password",
                        hint: "Create password",
                        isPassword: true,
                        isDark: isDark,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Required";
                          if (v.length < 6)
                            return "Must be at least 6 characters";
                          if (!RegExp(r'(?=.*[a-zA-Z])').hasMatch(v))
                            return "Must contain at least 1 letter";
                          if (!RegExp(r'(?=.*[\d\W])').hasMatch(v))
                            return "Must contain at least 1 number or symbol";
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              activeColor: primaryColor,
                              onChanged:
                                  (value) => setState(
                                    () => _agreedToTerms = value ?? false,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "I agree to the Terms of Service and Privacy Policy.",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    "Create Account",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType inputType = TextInputType.text,
    bool isPassword = false,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : const Color(0xFF0D141B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType: inputType,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF0D141B),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon:
                  isPassword
                      ? IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed:
                            () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
