import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final Set<String> selectedSeats;
  final String busName;
  final String busId;
  final String date;
  final Function() onPaymentSuccess;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    required this.selectedSeats,
    required this.busName,
    required this.busId,
    this.date = "2026-2-12",
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'card'; // 'apple', 'google', 'card', 'netbanking'

  void _processPayment() {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate Network Delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading
      widget.onPaymentSuccess(); // Execute the database booking logic

      // Show Success Dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Payment Successful!"),
          content: const Text("Your seats have been booked and ticket generated."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close Payment Screen
                Navigator.pop(context); // Close Seat Selection Screen
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                  Text(
                    "Payment",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // --- Main Content (Summary & Methods) ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Ticket Summary Card ---
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("BUS"),
                                  const SizedBox(height: 4),
                                  Text(widget.busName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildLabel("SEATS"),
                                  const SizedBox(height: 4),
                                  Text(widget.selectedSeats.join(", "), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_available_rounded, size: 20, color: Colors.grey[400]),
                                  const SizedBox(width: 8),
                                  Text(widget.date, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                              Text("\$${widget.totalAmount.toStringAsFixed(2)}",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Text("PAYMENT METHODS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 16),

                    // --- Digital Wallets Grid ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodCard("Apple Pay", _selectedMethod == 'apple', () => setState(() => _selectedMethod = 'apple')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMethodCard("Google Pay", _selectedMethod == 'google', () => setState(() => _selectedMethod = 'google')),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- Credit Card Card ---
                    GestureDetector(
                      onTap: () => setState(() => _selectedMethod = 'card'),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F2937) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedMethod == 'card' ? primary : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                            width: _selectedMethod == 'card' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.credit_card_rounded, color: primary),
                                    const SizedBox(width: 8),
                                    const Text("Credit / Debit Card", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _buildCardDot(Colors.red),
                                    const SizedBox(width: 4),
                                    _buildCardDot(Colors.orange),
                                  ],
                                ),
                              ],
                            ),
                            if (_selectedMethod == 'card') ...[
                              const SizedBox(height: 20),
                              _buildTextField("CARD NUMBER", "xxxx xxxx xxxx xxxx"),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField("EXPIRY", "MM/YY")),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTextField("CVV", "***")),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Space for bottom bar
                  ],
                ),
              ),
            ),

            // --- Bottom Payment Bar ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, -10))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("AMOUNT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("\$${widget.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("PAY NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey));

  Widget _buildMethodCard(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.1) : (isDark ? const Color(0xFF1F2937) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primary : (isDark ? Colors.grey[800]! : Colors.grey[200]!)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? primary : (isDark ? Colors.white : Colors.black))),
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildCardDot(Color color) => Container(width: 24, height: 16, decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(2)));

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black), onPressed: onTap),
    );
  }
}
