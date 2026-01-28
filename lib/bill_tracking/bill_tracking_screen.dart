import 'dart:async';

import 'package:flutter/material.dart';

import 'bill_tracking_firebase_service.dart';
import 'bill_tracking_models.dart';
import 'bill_tracking_views.dart';

class BillTrackingScreen extends StatefulWidget {
  const BillTrackingScreen({super.key});

  @override
  State<BillTrackingScreen> createState() => _BillTrackingScreenState();
}

class _BillTrackingScreenState extends State<BillTrackingScreen> {
  final BillTrackingFirebaseService _firebaseService =
      BillTrackingFirebaseService();

  BillTrackingView _view = BillTrackingView.dashboard;
  String? _activeGroupId;
  BillModel? _selectedBill;

  List<BillGroup> _groups = [];
  List<BillModel> _bills = [];

  StreamSubscription<List<BillGroup>>? _groupsSubscription;
  StreamSubscription<List<BillModel>>? _billsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _billsSubscription?.cancel();
    super.dispose();
  }

  void _loadData() {
    // Listen to groups changes in real-time
    _groupsSubscription = _firebaseService.getGroupsStream().listen((groups) {
      setState(() {
        _groups = groups;
        // If no active group is set and groups exist, set the first one
        if (_activeGroupId == null && groups.isNotEmpty) {
          _activeGroupId = groups.first.id;
          _loadBillsForActiveGroup();
        }
        _isLoading = false;
      });
    });
  }

  void _loadBillsForActiveGroup() {
    if (_activeGroupId == null) {
      setState(() {
        _bills = [];
      });
      return;
    }

    // Cancel previous subscription if any
    _billsSubscription?.cancel();

    // Listen to bills for the active group in real-time
    _billsSubscription = _firebaseService
        .getBillsStream(_activeGroupId!)
        .listen((bills) {
          setState(() {
            _bills = bills;
          });
        });
  }

  BillGroup? get _activeGroup {
    if (_activeGroupId == null || _groups.isEmpty) return null;
    try {
      return _groups.firstWhere((g) => g.id == _activeGroupId);
    } catch (_) {
      return _groups.isNotEmpty ? _groups.first : null;
    }
  }

  List<BillModel> get _activeBills =>
      _activeGroupId == null
          ? []
          : _bills.where((b) => b.groupId == _activeGroupId).toList();

  Future<void> _updateBill(BillModel bill) async {
    try {
      await _firebaseService.updateBill(bill);
      if (_selectedBill?.id == bill.id) {
        setState(() {
          _selectedBill = bill;
        });
      }
      // Data will be updated automatically via stream
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update bill: $e')));
      }
    }
  }

  Future<void> _createGroup(BillGroup group) async {
    try {
      await _firebaseService.createGroup(group);
      // Set as active group
      setState(() {
        _activeGroupId = group.id;
        _view = BillTrackingView.dashboard;
      });
      // Load bills for the new group
      _loadBillsForActiveGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
    }
  }

  Future<void> _createBill(BillModel bill) async {
    try {
      await _firebaseService.createBill(bill);
      setState(() {
        _view = BillTrackingView.dashboard;
      });
      // Data will be updated automatically via stream
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create bill: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _view == BillTrackingView.dashboard ||
          _view == BillTrackingView.history,
      onPopInvoked: (didPop) {
        if (!didPop &&
            _view != BillTrackingView.dashboard &&
            _view != BillTrackingView.history) {
          // Navigate to dashboard instead of popping
          setState(() => _view = BillTrackingView.dashboard);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          title: const Text('Bill Tracking'),
          leading:
              _view == BillTrackingView.dashboard ||
                      _view == BillTrackingView.history
                  ? null // Use default back button for dashboard/history (will pop to menu)
                  : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      // Navigate to dashboard instead of popping
                      setState(() => _view = BillTrackingView.dashboard);
                    },
                  ),
          automaticallyImplyLeading:
              _view == BillTrackingView.dashboard ||
              _view == BillTrackingView.history,
          actions: [
            if (_view == BillTrackingView.dashboard ||
                _view == BillTrackingView.history)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.public_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('MYR', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildBody(),
                ),
        floatingActionButton:
            _view == BillTrackingView.dashboard && _activeGroup != null
                ? FloatingActionButton(
                  onPressed:
                      () => setState(() => _view = BillTrackingView.createBill),
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                )
                : null,
        bottomNavigationBar:
            _view == BillTrackingView.dashboard ||
                    _view == BillTrackingView.history
                ? NavigationBar(
                  selectedIndex: _view == BillTrackingView.dashboard ? 0 : 1,
                  onDestinationSelected: (index) {
                    setState(() {
                      _view =
                          index == 0
                              ? BillTrackingView.dashboard
                              : BillTrackingView.history;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                  ],
                )
                : null,
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case BillTrackingView.dashboard:
        if (_activeGroup == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.group_add_rounded,
                  size: 80,
                  color: Colors.black26,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No groups yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a group to start tracking bills',
                  style: TextStyle(color: Colors.black38),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      () =>
                          setState(() => _view = BillTrackingView.createGroup),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Group'),
                ),
              ],
            ),
          );
        }
        return BillDashboard(
          group: _activeGroup!,
          groups: _groups,
          bills: _activeBills,
          onSwitchGroup: (id) {
            setState(() => _activeGroupId = id);
            _loadBillsForActiveGroup();
          },
          onCreateGroup:
              () => setState(() => _view = BillTrackingView.createGroup),
          onNewBill: () => setState(() => _view = BillTrackingView.createBill),
          onViewBill: (bill) {
            setState(() {
              _selectedBill = bill;
              _view = BillTrackingView.details;
            });
          },
        );
      case BillTrackingView.createGroup:
        return BillCreateGroup(
          onSave: _createGroup,
          onCancel: () => setState(() => _view = BillTrackingView.dashboard),
        );
      case BillTrackingView.history:
        return BillHistoryView(
          bills: _activeBills,
          onViewBill: (bill) {
            setState(() {
              _selectedBill = bill;
              _view = BillTrackingView.details;
            });
          },
        );
      case BillTrackingView.createBill:
        if (_activeGroup == null) {
          return const Center(child: Text('Please create a group first'));
        }
        return BillCreateBill(
          users: _activeGroup!.members,
          activeGroupId: _activeGroup!.id,
          onSave: _createBill,
          onCancel: () => setState(() => _view = BillTrackingView.dashboard),
        );
      case BillTrackingView.details:
        if (_activeGroup == null || _selectedBill == null) {
          return const Center(child: Text('Bill not found'));
        }
        return BillDetailsView(
          bill: _selectedBill!,
          users: _activeGroup!.members,
          onClose: () => setState(() => _view = BillTrackingView.dashboard),
          onUpdate: _updateBill,
        );
    }
  }
}
