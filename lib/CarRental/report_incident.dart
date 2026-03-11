import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ReportIncidentScreen extends StatefulWidget {
  final String bookingId;
  final String carId;
  final String carName;

  const ReportIncidentScreen({
    super.key,
    required this.bookingId,
    required this.carId,
    required this.carName,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  int _selectedIncidentType = 0; // 0 = Vehicle Damage, 1 = Theft / Loss

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  File? _frontPhoto;
  File? _rearPhoto;
  File? _sidePhoto;
  File? _closeUpPhoto;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String type) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 30,
    );
    if (pickedFile != null) {
      setState(() {
        if (type == 'front') _frontPhoto = File(pickedFile.path);
        if (type == 'rear') _rearPhoto = File(pickedFile.path);
        if (type == 'side') _sidePhoto = File(pickedFile.path);
        if (type == 'close') _closeUpPhoto = File(pickedFile.path);
      });
    }
  }

  // ⭐ BULLETPROOF SUBMIT LOGIC
  Future<void> _submitReport() async {
    // 1. Strict Validation
    final String locText = _locationController.text.trim();
    final String descText = _descController.text.trim();

    if (locText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the incident location."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (descText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please briefly describe the incident."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2. Safely encode the 4 images to Base64 so the Admin can see them
      List<String> encodedImages = [];
      for (var file in [_frontPhoto, _rearPhoto, _sidePhoto, _closeUpPhoto]) {
        if (file != null) {
          final bytes = await file.readAsBytes();
          encodedImages.add(base64Encode(bytes));
        }
      }

      // Require at least one photo for Damage reports
      if (_selectedIncidentType == 0 && encodedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("At least one photo is required for Vehicle Damage."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // 3. Build a completely Type-Safe map for Firebase
      final String incidentTypeString =
          _selectedIncidentType == 0 ? 'Vehicle Damage' : 'Theft / Loss';

      Map<String, dynamic> reportData = {
        'status': 'Incident Reported',
        'incidentType': incidentTypeString,
        'incidentLocation': locText,
        'incidentDescription': descText,
        'reportedAt': FieldValue.serverTimestamp(),
      };

      // Only inject images if they exist to prevent Null cast errors on the Profile Stream
      if (encodedImages.isNotEmpty) {
        reportData['proofImages'] = encodedImages;
        reportData['proofImage'] =
            encodedImages.first; // Fallback for single-image admin viewers
      }

      // 4. Update the booking securely using set with merge
      await FirebaseFirestore.instance
          .collection('car_bookings')
          .doc(widget.bookingId)
          .set(reportData, SetOptions(merge: true));

      // 5. Lock the car to 'unavailable' so it instantly vanishes from the rental map
      if (widget.carId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('rental_cars')
              .doc(widget.carId)
              .update({'status': 'unavailable'});
        } catch (e) {}
      }

      // Fallback: sweep by name if ID was missing in old test data
      if (widget.carName.isNotEmpty) {
        try {
          var carQuery =
              await FirebaseFirestore.instance
                  .collection('rental_cars')
                  .where('name', isEqualTo: widget.carName)
                  .get();
          for (var doc in carQuery.docs) {
            await FirebaseFirestore.instance
                .collection('rental_cars')
                .doc(doc.id)
                .update({'status': 'unavailable'});
          }
        } catch (e) {}
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Report Submitted",
                  textAlign: TextAlign.center,
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text(
                      "Your incident report has been securely submitted. Our team will review the details and contact you shortly.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137FEC),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.pop(context);
                    },
                    child: const Text("Back to Profile"),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error Submitting: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primaryColor = Color(0xFF137FEC);
    final bgColor = isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8);
    final surfaceColor = isDark ? const Color(0xFF1A242D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor.withOpacity(0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Report Incident",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.support_agent,
              color: primaryColor,
              size: 20,
            ),
            label: const Text(
              "Help",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(right: 16),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body:
          _isSubmitting
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Securely Uploading Report & Photos..."),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Incident Type Selector
                    Text(
                      "What happened?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  () =>
                                      setState(() => _selectedIncidentType = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedIncidentType == 0
                                          ? (isDark
                                              ? const Color(0xFF334155)
                                              : Colors.white)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      _selectedIncidentType == 0
                                          ? Border.all(
                                            color:
                                                isDark
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFFE2E8F0),
                                          )
                                          : null,
                                  boxShadow:
                                      _selectedIncidentType == 0
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                          : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Vehicle Damage",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color:
                                        _selectedIncidentType == 0
                                            ? (isDark
                                                ? Colors.white
                                                : primaryColor)
                                            : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  () =>
                                      setState(() => _selectedIncidentType = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedIncidentType == 1
                                          ? (isDark
                                              ? const Color(0xFF334155)
                                              : Colors.white)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      _selectedIncidentType == 1
                                          ? Border.all(
                                            color:
                                                isDark
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFFE2E8F0),
                                          )
                                          : null,
                                  boxShadow:
                                      _selectedIncidentType == 1
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                          : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Theft / Loss",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color:
                                        _selectedIncidentType == 1
                                            ? (isDark
                                                ? Colors.white
                                                : primaryColor)
                                            : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Evidence Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Evidence",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.blue.shade900.withOpacity(0.3)
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Camera Only",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please take 4 photos of the vehicle damage. Photos must be taken now to be valid.",
                      style: TextStyle(
                        fontSize: 14,
                        color: textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 4 / 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildPhotoSlot(
                          "Front Angle",
                          _frontPhoto,
                          () => _takePhoto('front'),
                          isDark,
                        ),
                        _buildPhotoSlot(
                          "Rear Angle",
                          _rearPhoto,
                          () => _takePhoto('rear'),
                          isDark,
                        ),
                        _buildPhotoSlot(
                          "Side / Impact",
                          _sidePhoto,
                          () => _takePhoto('side'),
                          isDark,
                        ),
                        _buildPhotoSlot(
                          "Close-up",
                          _closeUpPhoto,
                          () => _takePhoto('close'),
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Details Section
                    Text(
                      "Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Editable Location Input
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "INCIDENT LOCATION",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextField(
                                  controller: _locationController,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    border: InputBorder.none,
                                    hintText:
                                        "Enter the exact street or landmark...",
                                    hintStyle: TextStyle(
                                      color: textMuted.withOpacity(0.6),
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Input
                    Text(
                      "Briefly describe how the incident occurred",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            "E.g. I was backing out of a parking spot and scratched the bumper against a pillar...",
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: surfaceColor,
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Financial Impact Section
                    Text(
                      "Financial Impact & Status",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.orange.shade900.withOpacity(0.1)
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.orange.shade900.withOpacity(0.3)
                                  : Colors.orange.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.orange.shade800.withOpacity(0.3)
                                      : Colors.orange.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.payments,
                              color:
                                  isDark
                                      ? Colors.orange.shade400
                                      : Colors.orange.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Deposit Frozen (\$500.00)",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.orange.shade100
                                            : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Your security deposit will be temporarily held while our team reviews the damage. You will be notified of the final cost within 48 hours.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color:
                                        isDark
                                            ? Colors.orange.shade200
                                            : Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "VEHICLE STATUS: UNSAFE TO DRIVE",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? Colors.red.shade400
                                                : Colors.red.shade600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

      // 5. Sticky Footer
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: ElevatedButton(
          onPressed: _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: primaryColor.withOpacity(0.4),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Submit Report",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.send, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(
    String label,
    File? file,
    VoidCallback onTap,
    bool isDark,
  ) {
    return CustomPaint(
      painter: DashedRectPainter(
        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        strokeWidth: 2,
        gap: 6,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color:
                isDark
                    ? const Color(0xFF1E293B).withOpacity(0.5)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              file != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        Container(color: Colors.black.withOpacity(0.3)),
                        const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF334155) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          color: Color(0xFF137FEC),
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

// Custom Painter for the Dashed Border around the image upload slots
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;
    var path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(12),
          ),
        );
    Path dashedPath = Path();
    double dashWidth = 8.0;
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashedPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + gap;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
