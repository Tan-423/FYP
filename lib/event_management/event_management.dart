import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

part 'event_models.dart';
part 'event_actions.dart';
part 'event_views.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen>
    with EventManagementActions, EventManagementViews {
  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Column(
          children: [
            _buildNotificationBar(),
            Expanded(child: _buildContent()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }
}
