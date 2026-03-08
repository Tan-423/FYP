import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class CancelBookingScreen extends StatefulWidget {
  final String bookingId;
  final String carId;
  final String carName;
  final String imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String confirmationNo;

  const CancelBookingScreen({
    super.key,
    required this.bookingId,
    required this.carId,
    required this.carName,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.confirmationNo,
  });

  @override
  State<CancelBookingScreen> createState() => _CancelBookingScreenState();
}

class _CancelBookingScreenState extends State<CancelBookingScreen> {
  String? _selectedReason;
  bool _isSubmitting = false;
  File? _proofImage;

  final Color _primaryColor = const Color(0xFF137FEC);
  final Color _bgColor = const Color(0xFFF6F7F8);
  final Color _textColor = const Color(0xFF111418);
  final Color _textMuted = const Color(0xFF617589);
  final Color _borderColor = const Color(0xFFE5E7EB);
  final Color _borderDark = const Color(0xFFDBE0E6);

  Widget _buildDynamicImage(String imageString) {
    if (imageString.isEmpty) return Container(color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey));
    if (imageString.startsWith('http')) return Image.network(imageString, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]));
    try {
      String cleanBase64 = imageString.contains(',') ? imageString.split(',').last : imageString;
      return Image.memory(base64Decode(cleanBase64), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]));
    } catch (e) { return Container(color: Colors.grey[200]); }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 30);
    if (pickedFile != null) {
      setState(() => _proofImage = File(pickedFile.path));
    }
  }

  // ⭐ BRUTE FORCE DATABASE SWEEP
  Future<void> _submitCancellation(double finalRefund, double fee) async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a reason for cancellation."), backgroundColor: Colors.red));
      return;
    }

    if (_selectedReason == 'damage' && _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo proof is required for vehicle condition issues."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? base64Image;
      if (_proofImage != null) {
        List<int> imageBytes = await _proofImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      // Safely build the booking update payload
      Map<String, dynamic> bookingUpdateData = {
        'refundAmount': finalRefund,
        'cancellationFee': fee,
        'cancellationReason': _selectedReason,
        'cancelledAt': FieldValue.serverTimestamp(),
      };
      if (base64Image != null) bookingUpdateData['proofImage'] = base64Image;

      // ========================================================
      // SCENARIO 1: DAMAGE REPORT (Sent to Admin)
      // ========================================================
      if (_selectedReason == 'damage') {
        bookingUpdateData['status'] = 'Pending Cancellation';
        await FirebaseFirestore.instance.collection('car_bookings').doc(widget.bookingId).update(bookingUpdateData);

        // Lock the car from the map so nobody else books it
        var carsQuery = await FirebaseFirestore.instance.collection('rental_cars').where('name', isEqualTo: widget.carName).get();
        for (var doc in carsQuery.docs) {
          await FirebaseFirestore.instance.collection('rental_cars').doc(doc.id).update({'status': 'maintenance'});
        }

        if (mounted) {
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text("Sent for Review", textAlign: TextAlign.center),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.orange, size: 64), SizedBox(height: 16),
                    Text("Your request has been submitted. An admin will review your photos and issue the appropriate refund shortly.", textAlign: TextAlign.center),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
                      onPressed: () { Navigator.pop(c); Navigator.pop(context); },
                      child: const Text("Back to Profile")
                  )
                ],
              )
          );
        }
      }
      // ========================================================
      // SCENARIO 2: NORMAL CANCEL (Free up the car strictly)
      // ========================================================
      else {
        bookingUpdateData['status'] = 'Cancelled';
        await FirebaseFirestore.instance.collection('car_bookings').doc(widget.bookingId).update(bookingUpdateData);

        // 1. Generate exact absolute calendar dates to remove (Ignores timezone/time offsets)
        List<String> datesToCancel = [];
        DateTime current = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
        DateTime end = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

        while (!current.isAfter(end)) {
          datesToCancel.add(DateFormat('yyyy-MM-dd').format(current));
          current = current.add(const Duration(days: 1));
        }

        // 2. Perform a Brute Force Sweep on the Cars Collection
        var carQuery = await FirebaseFirestore.instance.collection('rental_cars').where('name', isEqualTo: widget.carName).get();
        for (var doc in carQuery.docs) {

          // Manually scrub the array in memory
          List<dynamic> dbDates = List.from(doc.data()['bookedDates'] ?? []);
          dbDates.removeWhere((d) => datesToCancel.contains(d.toString()));

          // Force push the cleaned array and available status
          await FirebaseFirestore.instance.collection('rental_cars').doc(doc.id).update({
            'bookedDates': dbDates,
            'status': 'available'
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Cancelled Successfully."), backgroundColor: Colors.redAccent));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateRange = "${DateFormat('MMM d').format(widget.startDate)} - ${DateFormat('MMM d').format(widget.endDate)}";

    DateTime pickupTime = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day, 10, 0);
    DateTime now = DateTime.now();

    double refundAmount = 0.0;
    double cancellationFee = 0.0;
    String refundStatusText = "";
    Color refundStatusColor = Colors.green;
    Color refundBgColor = Colors.green.shade50;

    if (now.isBefore(pickupTime.subtract(const Duration(hours: 24)))) {
      refundAmount = widget.totalPrice;
      cancellationFee = 0.0;
      refundStatusText = "Eligible for Full Refund";
      refundStatusColor = Colors.green;
      refundBgColor = Colors.green.shade50;
    } else if (now.isBefore(pickupTime)) {
      cancellationFee = widget.totalPrice * 0.5;
      refundAmount = widget.totalPrice - cancellationFee;
      refundStatusText = "Late Cancellation (50% Refund)";
      refundStatusColor = Colors.orange.shade700;
      refundBgColor = Colors.orange.shade50;
    } else {
      cancellationFee = widget.totalPrice;
      refundAmount = 0.0;
      refundStatusText = "Non-refundable";
      refundStatusColor = Colors.red;
      refundBgColor = Colors.red.shade50;
    }

    bool isDamageReport = _selectedReason == 'damage';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F2F4), height: 1),
        ),
        leading: Center(
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: _textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          "Cancel Booking",
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Booking Summary Card
                  _buildSectionHeader("Booking to Cancel"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.carName, style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Ref: #${widget.confirmationNo}", style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month, size: 14, color: _textMuted),
                                    const SizedBox(width: 6),
                                    Text(dateRange, style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: _buildDynamicImage(widget.imageUrl),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Reason Selector
                  _buildSectionHeader("Reason for Cancellation"),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedReason,
                    icon: const Icon(Icons.expand_more, color: Colors.grey),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderDark)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderDark)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 2)),
                    ),
                    hint: const Text("Select a reason"),
                    items: const [
                      DropdownMenuItem(value: "plans", child: Text("Change of plans")),
                      DropdownMenuItem(value: "price", child: Text("Found a better price")),
                      DropdownMenuItem(value: "damage", child: Text("Vehicle condition / Damage")),
                      DropdownMenuItem(value: "other", child: Text("Other reason")),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Photo Upload
                  Row(
                    children: [
                      _buildSectionHeader(isDamageReport ? "Proof of Issue (Required)" : "Proof of Issue (Optional)"),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline, size: 14, color: isDamageReport ? Colors.red : Colors.grey.shade400)
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isDamageReport)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text("Because you selected vehicle condition/damage, a photo is required for administrative review.", style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),

                  CustomPaint(
                    painter: DashedRectPainter(color: isDamageReport && _proofImage == null ? Colors.red.shade300 : _borderDark, strokeWidth: 2, gap: 6),
                    child: InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: _proofImage != null ? 200 : null,
                        padding: _proofImage != null ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: isDamageReport && _proofImage == null ? Colors.red.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _proofImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_proofImage!, fit: BoxFit.cover),
                              Container(color: Colors.black.withOpacity(0.3)),
                              const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 48)),
                              const Positioned(bottom: 12, right: 12, child: Text("Tap to retake", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                            ],
                          ),
                        )
                            : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                              child: Icon(Icons.add_a_photo, color: isDamageReport ? Colors.red : _primaryColor, size: 20),
                            ),
                            const SizedBox(height: 12),
                            Text("Tap to upload photos", style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("Supports JPG, PNG (Max 5MB)", style: TextStyle(color: _textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Refund Details & Timeline
                  if (!isDamageReport) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader("Refund Policy"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: refundBgColor, borderRadius: BorderRadius.circular(20)),
                          child: Text(refundStatusText, style: TextStyle(color: refundStatusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildTimelineStep(icon: Icons.check, iconColor: Colors.green, bgColor: Colors.green.shade50, title: "Free Cancellation", subtitle: "Until ${DateFormat('MMM d, h:mm a').format(pickupTime.subtract(const Duration(hours: 24)))}", isLast: false, isFaded: cancellationFee > 0),
                          _buildTimelineStep(icon: Icons.warning_amber_rounded, iconColor: Colors.orange, bgColor: Colors.orange.shade50, title: "50% Partial Refund", subtitle: "Within 24 hours of pickup", isLast: false, isFaded: refundAmount == 0),
                          _buildTimelineStep(icon: Icons.block, iconColor: Colors.red, bgColor: Colors.red.shade50, title: "Non-refundable", subtitle: "After ${DateFormat('MMM d, h:mm a').format(pickupTime)}", isLast: true, isFaded: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader("Refund Details"),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total Paid", style: TextStyle(color: _textMuted, fontSize: 14)), Text("\$${widget.totalPrice.toStringAsFixed(2)}", style: TextStyle(color: _textMuted, fontSize: 14))]),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Cancellation Fee", style: TextStyle(color: _textMuted, fontSize: 14)), Text("-\$${cancellationFee.toStringAsFixed(2)}", style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 14))]),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: _borderDark, height: 1)),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text("Estimated Refund", style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("\$${refundAmount.toStringAsFixed(2)}", style: TextStyle(color: refundAmount > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 20))
                          ]),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ⭐ ADMIN REVIEW UI FOR DAMAGE REPORTS
                    _buildSectionHeader("Admin Review Status"),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text("Pending Investigation", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Because you are reporting damage or vehicle condition issues, standard cancellation policies are paused. An admin will review your uploaded photos and determine the full refund amount.", style: TextStyle(color: Colors.orange.shade800, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF0F2F4))),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => _submitCancellation(refundAmount, cancellationFee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDamageReport ? Colors.orange.shade600 : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isDamageReport ? "Submit to Admin" : "Confirm Cancellation", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: _borderDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Keep Booking", style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 0.5));
  }

  Widget _buildTimelineStep({required IconData icon, required Color iconColor, required Color bgColor, required String title, required String subtitle, required bool isLast, required bool isFaded}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, size: 16, color: iconColor)),
            if (!isLast) Container(width: 2, height: 36, color: _borderDark, margin: const EdgeInsets.symmetric(vertical: 4)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Opacity(
            opacity: isFaded ? 0.4 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: isFaded ? FontWeight.w600 : FontWeight.bold, fontSize: 14, color: _textColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 12)),
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  DashedRectPainter({required this.color, required this.strokeWidth, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
    var path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)));
    Path dashedPath = Path();
    double dashWidth = 8.0;
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashedPath.addPath(pathMetric.extractPath(distance, distance + dashWidth), Offset.zero);
        distance += dashWidth + gap;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashedPath, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}