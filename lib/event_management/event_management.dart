import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../secondary_firebase.dart';

part 'event_models.dart';
part 'event_actions.dart';
part 'event_views.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key, this.retryPaymentId});

  final String? retryPaymentId;

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen>
    with EventManagementActions, EventManagementViews {
  bool _didResumePayment = false;

  @override
  void initState() {
    super.initState();
    final retryId = widget.retryPaymentId;
    if (retryId != null && retryId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didResumePayment) return;
        _didResumePayment = true;
        _resumePaymentFromId(retryId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _ticketTotalController.dispose();
    _ticketRemainingController.dispose();
    _organizerEmailController.dispose();
    _organizerPasswordController.dispose();
    _newCategoryController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildContent()),
                _buildBottomNav(),
              ],
            ),
            _buildNotificationBar(),
          ],
        ),
      ),
    );
  }
}
