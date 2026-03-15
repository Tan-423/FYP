import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final Set<String> selectedSeats;
  final String busName;
  final String busId;
  final String date;
  final Future<void> Function({String? paymentId, String? payerEmail}) onPaymentSuccess;

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
  static const String _paypalBaseUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net';
  static const String _paypalReturnUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalSuccess';
  static const String _paypalCancelUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalCancel';

  bool _isCreatingPayment = false;
  bool _isCapturingPayment = false;
  String? _paymentOrderId;
  WebViewController? _webViewController;

  final CollectionReference<Map<String, dynamic>> _paymentsRef =
      FirebaseFirestore.instance.collection('BusPayments');

  Future<void> _startPayPalCheckout() async {
    if (_isCreatingPayment) return;
    setState(() => _isCreatingPayment = true);

    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': widget.totalAmount.toStringAsFixed(2),
          'currency': 'MYR',
          'return_url': _paypalReturnUrl,
          'cancel_url': _paypalCancelUrl,
          'event_id': widget.busId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Order creation failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final approvalUrl = data['approvalUrl']?.toString();
      final orderId = data['orderId']?.toString();

      if (approvalUrl == null || orderId == null) {
        throw Exception('Missing approval data from server');
      }

      final user = FirebaseAuth.instance.currentUser;
      await _paymentsRef.doc(orderId).set({
        'PaymentId': orderId,
        'BusId': widget.busId,
        'BusName': widget.busName,
        'UserId': user?.uid ?? 'guest',
        'Seats': widget.selectedSeats.toList(),
        'Amount': widget.totalAmount,
        'Currency': 'MYR',
        'TravelDate': widget.date,
        'Status': 'CREATED',
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith(_paypalReturnUrl)) {
                _capturePayPalOrder();
                return NavigationDecision.prevent;
              }
              if (url.startsWith(_paypalCancelUrl)) {
                _cancelPayPalCheckout();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(approvalUrl));

      if (!mounted) return;
      setState(() {
        _paymentOrderId = orderId;
        _webViewController = controller;
        _isCreatingPayment = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start PayPal checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _capturePayPalOrder() async {
    if (_paymentOrderId == null || _isCapturingPayment) return;
    setState(() => _isCapturingPayment = true);

    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/capturePayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': _paymentOrderId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Capture failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payerEmail =
          data['data']?['payer']?['email_address']?.toString();
      final orderId = _paymentOrderId;

      await _paymentsRef.doc(orderId).set({
        'PaymentId': orderId,
        'Status': 'CAPTURED',
        'CapturedAt': FieldValue.serverTimestamp(),
        'PayerEmail': payerEmail,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isCapturingPayment = false;
        _webViewController = null;
        _paymentOrderId = null;
      });

      await widget.onPaymentSuccess(paymentId: orderId, payerEmail: payerEmail);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Payment Successful!"),
            content: const Text(
                "Your seats have been booked and ticket generated."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close PaymentScreen
                  Navigator.pop(context); // close SeatSelectionScreen
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (_paymentOrderId != null) {
        _paymentsRef.doc(_paymentOrderId).set({
          'PaymentId': _paymentOrderId,
          'Status': 'FAILED',
          'UpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) {
        setState(() {
          _isCapturingPayment = false;
          _webViewController = null;
          _paymentOrderId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelPayPalCheckout() {
    if (_paymentOrderId != null) {
      _paymentsRef.doc(_paymentOrderId).set({
        'PaymentId': _paymentOrderId,
        'Status': 'CANCELLED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    setState(() {
      _webViewController = null;
      _paymentOrderId = null;
      _isCreatingPayment = false;
      _isCapturingPayment = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);

    // Show PayPal WebView when order has been created
    if (_webViewController != null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF1F2937) : Colors.white,
          elevation: 0,
          title: const Text('PayPal Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelPayPalCheckout,
          ),
        ),
        body: _isCapturingPayment
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Confirming payment...',
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              )
            : WebViewWidget(controller: _webViewController!),
      );
    }

    // Normal payment summary screen
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconBtn(Icons.arrow_back_ios_new_rounded,
                      () => Navigator.pop(context)),
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

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticket Summary Card
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("BUS"),
                                  const SizedBox(height: 4),
                                  Text(widget.busName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildLabel("SEATS"),
                                  const SizedBox(height: 4),
                                  Text(widget.selectedSeats.join(", "),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200]),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_available_rounded,
                                      size: 20, color: Colors.grey[400]),
                                  const SizedBox(width: 8),
                                  Text(widget.date,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[500])),
                                ],
                              ),
                              Text(
                                "MYR ${widget.totalAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      "PAYMENT METHOD",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),

                    // PayPal Info Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary, width: 2),
                      ),
                      child: Row(
                        children: [
                          _buildPayPalLogo(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "PayPal",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "You will be securely redirected to PayPal to complete your payment.",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle,
                              color: primary, size: 22),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          "Payments are secure and encrypted",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // Bottom Pay Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, -10))
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("AMOUNT",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      Text(
                        "MYR ${widget.totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingPayment ? null : _startPayPalCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isCreatingPayment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("PAY WITH PAYPAL",
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildPayPalLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF003087),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Pay',
            style: TextStyle(
              color: Color(0xFF009CDE),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF009CDE),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Pal',
            style: TextStyle(
              color: Color(0xFF003087),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey));

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: IconButton(
          icon: Icon(icon,
              size: 18,
              color: isDark ? Colors.white : Colors.black),
          onPressed: onTap),
    );
  }
}
