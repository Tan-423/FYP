import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_tracking_models.dart';
import 'bill_tracking_widgets.dart';

class BillDashboard extends StatelessWidget {
  const BillDashboard({
    required this.group,
    required this.groups,
    required this.bills,
    required this.onSwitchGroup,
    required this.onCreateGroup,
    required this.onNewBill,
    required this.onViewBill,
    super.key,
  });

  final BillGroup group;
  final List<BillGroup> groups;
  final List<BillModel> bills;
  final ValueChanged<String> onSwitchGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onNewBill;
  final ValueChanged<BillModel> onViewBill;

  @override
  Widget build(BuildContext context) {
    // TODO: Update this with actual current user ID from Firebase Auth
    final currentUserId =
        group.members.isNotEmpty ? group.members.first.id : '';

    final myTotalOwe = bills.fold<double>(0, (acc, bill) {
      if (bill.payerId == currentUserId) return acc;
      if (bill.memberStatuses[currentUserId] == BillStatus.settled) return acc;
      final splits = calculateUserSplits(bill, group.members);
      return acc + (splits[currentUserId]?.total ?? 0) * bill.exchangeRate;
    });

    final totalSpent = bills.fold<double>(
      0,
      (acc, bill) => acc + (bill.totalAmount * bill.exchangeRate),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        BillGroupSelector(
          group: group,
          groups: groups,
          onSwitchGroup: onSwitchGroup,
          onCreateGroup: onCreateGroup,
        ),
        const SizedBox(height: 16),
        BillSummaryCard(
          totalSpent: totalSpent,
          myTotalOwe: myTotalOwe,
          settledCount:
              bills.where((b) => b.status == BillStatus.settled).length,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Scan Bill',
                subtitle: 'AI auto-split',
                icon: Icons.photo_camera_rounded,
                color: const Color(0xFF2563EB),
                onTap: onNewBill,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: QuickActionCard(
                title: 'Settle Up',
                subtitle: 'Clear debts',
                icon: Icons.refresh_rounded,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Bills',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: onNewBill, child: const Text('New Bill')),
          ],
        ),
        const SizedBox(height: 8),
        if (bills.isEmpty)
          EmptyState(
            message: 'No bills in this group yet.',
            actionLabel: 'Create First Bill',
            onAction: onNewBill,
          )
        else
          ...bills
              .take(3)
              .map(
                (bill) =>
                    BillListItem(bill: bill, onTap: () => onViewBill(bill)),
              ),
      ],
    );
  }
}

class BillHistoryView extends StatefulWidget {
  const BillHistoryView({
    required this.bills,
    required this.onViewBill,
    super.key,
  });

  final List<BillModel> bills;
  final ValueChanged<BillModel> onViewBill;

  @override
  State<BillHistoryView> createState() => _BillHistoryViewState();
}

class _BillHistoryViewState extends State<BillHistoryView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.bills]..sort((a, b) => b.date.compareTo(a.date));

    final filtered =
        sorted.where((bill) {
          if (_filter == 'All') return true;
          if (_filter == 'Settled') return bill.status == BillStatus.settled;
          if (_filter == 'Pending') return bill.status == BillStatus.pending;
          // TODO: Add 'Paid by Me' filter when Firebase Auth is integrated
          return true;
        }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search bills, items...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final label in ['All', 'Settled', 'Pending'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _filter == label,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No transactions found'),
            ),
          )
        else
          ...filtered.map(
            (bill) =>
                BillListItem(bill: bill, onTap: () => widget.onViewBill(bill)),
          ),
      ],
    );
  }
}

class BillCreateGroup extends StatefulWidget {
  const BillCreateGroup({
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final ValueChanged<BillGroup> onSave;
  final VoidCallback onCancel;

  @override
  State<BillCreateGroup> createState() => _BillCreateGroupState();
}

class _BillCreateGroupState extends State<BillCreateGroup> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  final List<BillUser> _members = [];

  void _addMember() {
    if (_memberController.text.trim().isEmpty) return;
    final name = _memberController.text.trim();
    setState(() {
      _members.add(
        BillUser(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          avatarUrl: 'https://i.pravatar.cc/150?u=$name',
        ),
      );
      _memberController.clear();
    });
  }

  void _removeMember(BillUser user) {
    setState(() => _members.remove(user));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'New Group',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('Create a group to split bills with.'),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Group Name',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Members (${_members.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in _members)
              Chip(
                avatar: CircleAvatar(
                  backgroundImage: NetworkImage(member.avatarUrl),
                ),
                label: Text(member.name),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeMember(member),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _memberController,
                decoration: InputDecoration(
                  hintText: 'Add member name...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addMember(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addMember,
              icon: const Icon(Icons.add_circle_rounded),
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty || _members.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter group name and add at least one member',
                        ),
                      ),
                    );
                    return;
                  }
                  widget.onSave(
                    BillGroup(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name,
                      members: List.of(_members),
                    ),
                  );
                },
                child: const Text('Create Group'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BillCreateBill extends StatefulWidget {
  const BillCreateBill({
    required this.users,
    required this.activeGroupId,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final List<BillUser> users;
  final String activeGroupId;
  final ValueChanged<BillModel> onSave;
  final VoidCallback onCancel;

  @override
  State<BillCreateBill> createState() => _BillCreateBillState();
}

class _BillCreateBillState extends State<BillCreateBill> {
  int _step = 1;
  String _title = '';
  String _currency = 'MYR';
  late String _payerId;
  double _sst = 6;
  double _serviceCharge = 10;
  final List<BillItem> _items = [];
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool _isScanning = false;
  List<BillItem>? _scannedItems; // Holds scanned items before confirmation

  @override
  void initState() {
    super.initState();
    _payerId = widget.users.isNotEmpty ? widget.users.first.id : '';
  }

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showScanOptions() async {
    if (_isScanning) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Open Camera'),
                onTap: () => _pickReceiptImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickReceiptImage(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    Navigator.of(context).pop();
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;
    final originalPath = picked.path;
    final croppedPath = await _cropReceipt(picked.path);
    if (croppedPath == null) return;
    setState(() => _isScanning = true);
    try {
      final items = await _scanReceiptWithFallback(croppedPath, originalPath);
      if (!mounted) return;
      if (items.isEmpty) {
        _showSnackBar(
          'No items detected. Try tighter crop and better lighting.',
        );
        return;
      }
      _applyScannedItems(items);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to scan this receipt. Try another photo.');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<String?> _cropReceipt(String path) async {
    final result = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Receipt',
          toolbarColor: const Color(0xFF2563EB),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    return result?.path;
  }

  Future<List<BillItem>> _scanReceiptWithFallback(
    String croppedPath,
    String originalPath,
  ) async {
    try {
      return await _scanReceipt(croppedPath);
    } catch (_) {
      if (croppedPath == originalPath) rethrow;
      return _scanReceipt(originalPath);
    }
  }

  Future<List<BillItem>> _scanReceipt(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(path);
    final recognized = await recognizer.processImage(inputImage);
    await recognizer.close();
    return _parseReceiptItems(recognized.text);
  }

  List<BillItem> _parseReceiptItems(String rawText) {
    final lines = rawText.split('\n');
    final items = <BillItem>[];
    final pricePattern = RegExp(r'(\d+[\.,]\d{2})');
    String? previousLine;

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      if (_isIgnoredLine(lower)) {
        previousLine = null;
        continue;
      }

      // Look for any price in the line
      final matches = pricePattern.allMatches(trimmed);
      if (matches.isEmpty) {
        // No price, save as potential item name
        if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
          previousLine = trimmed;
        }
        continue;
      }

      // Found price(s), use the last one
      final lastMatch = matches.last;
      final priceStr = lastMatch.group(1)!.replaceAll(',', '.');
      final amount = double.tryParse(priceStr) ?? 0;
      if (amount <= 0) {
        previousLine = null;
        continue;
      }

      // Try to extract name from same line first
      var name = trimmed.substring(0, lastMatch.start).trim();

      // Clean up common patterns in the name part
      name = name.replaceAll(
        RegExp(r'\s+(RM|MYR|rm)\s*$', caseSensitive: false),
        '',
      );
      name = name.replaceAll(RegExp(r'^\d+\s+'), ''); // Remove leading numbers
      name = name.replaceAll(RegExp(r'\s{2,}'), ' '); // Normalize spaces
      name = name.trim();

      // If name is too short or empty, use previous line
      if (name.length < 2 && previousLine != null) {
        name = previousLine;
        previousLine = null;
      }

      // If still no name, create a placeholder
      if (name.isEmpty) {
        name = 'Item ${items.length + 1}';
      }

      items.add(
        BillItem(
          id: '${DateTime.now().microsecondsSinceEpoch}-${items.length}',
          name: name,
          price: amount,
          assignedTo: widget.users.map((u) => u.id).toList(),
        ),
      );

      previousLine = null;
    }

    return items;
  }

  bool _isIgnoredLine(String text) {
    const ignoreKeywords = [
      'total',
      'subtotal',
      'sst',
      'service',
      'service charge',
      'tax',
      'gst',
      'change',
      'cash',
      'rounding',
      'discount',
      'amount due',
      'balance',
    ];
    for (final keyword in ignoreKeywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  void _applyScannedItems(List<BillItem> items) {
    setState(() {
      _scannedItems = items;
      _isScanning = false;
    });
  }

  void _confirmScannedBill() {
    if (_scannedItems == null) return;

    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    _nameControllers.clear();
    _priceControllers.clear();

    setState(() {
      _items
        ..clear()
        ..addAll(_scannedItems!);
      for (final item in _items) {
        _nameControllers[item.id] = TextEditingController(text: item.name);
        _priceControllers[item.id] = TextEditingController(
          text: item.price.toStringAsFixed(2),
        );
      }
      _scannedItems = null; // Clear scanned items
      _step = 2; // Move to item review step
    });
  }

  void _cancelScan() {
    setState(() {
      _scannedItems = null;
      _isScanning = false;
    });
  }

  Widget _buildScannedConfirmationScreen() {
    final scannedCount = _scannedItems?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receipt Scanned Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$scannedCount item${scannedCount > 1 ? 's' : ''} detected',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Preview of scanned items
        Text(
          'Scanned Items Preview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            itemCount: scannedCount,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final item = _scannedItems![index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    'RM ${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bill Details',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Bill Title',
            filled: true,
            fillColor: Colors.white,
          ),
          controller: TextEditingController(text: _title)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: _title.length),
            ),
          onChanged: (value) => _title = value,
        ),
        const SizedBox(height: 12),
        Text(
          'Who paid?',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final user in widget.users)
              ChoiceChip(
                label: Text(user.name),
                selected: _payerId == user.id,
                onSelected: (_) => setState(() => _payerId = user.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Currency',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final curr in billCurrencies.keys)
              ChoiceChip(
                label: Text(curr),
                selected: _currency == curr,
                onSelected: (_) => setState(() => _currency = curr),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'SST (%)',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _sst.toString()),
                onChanged: (value) => _sst = double.tryParse(value) ?? _sst,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Service (%)',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: _serviceCharge.toString(),
                ),
                onChanged:
                    (value) =>
                        _serviceCharge =
                            double.tryParse(value) ?? _serviceCharge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _confirmScannedBill,
          child: const Text('Confirm & Review Items'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _cancelScan,
          child: const Text('Cancel & Rescan'),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addItem() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _items.add(
        BillItem(
          id: id,
          name: '',
          price: 0,
          assignedTo: widget.users.map((u) => u.id).toList(),
        ),
      );
    });
    _nameControllers[id] = TextEditingController();
    _priceControllers[id] = TextEditingController(text: '0');
  }

  void _updateItem(
    String itemId, {
    String? name,
    double? price,
    List<String>? assignedTo,
  }) {
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].id == itemId) {
          _items[i] = BillItem(
            id: _items[i].id,
            name: name ?? _items[i].name,
            price: price ?? _items[i].price,
            assignedTo: assignedTo ?? _items[i].assignedTo,
          );
        }
      }
    });
  }

  double _calculateTotal() {
    final subtotal = _items.fold<double>(0, (acc, item) => acc + item.price);
    final tax = subtotal * (_sst / 100);
    final svc = subtotal * (_serviceCharge / 100);
    return subtotal + tax + svc;
  }

  void _saveBill() {
    final initialStatuses = <String, BillStatus>{};
    for (final user in widget.users) {
      initialStatuses[user.id] =
          user.id == _payerId ? BillStatus.settled : BillStatus.pending;
    }

    final exchangeRate =
        billCurrencies['MYR']!.rate / billCurrencies[_currency]!.rate;

    widget.onSave(
      BillModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        groupId: widget.activeGroupId,
        title: _title.isEmpty ? 'New Bill' : _title,
        date: DateTime.now(),
        totalAmount: _calculateTotal(),
        currency: _currency,
        exchangeRate: exchangeRate,
        items: List.of(_items),
        sst: _sst,
        serviceCharge: _serviceCharge,
        payerId: _payerId,
        status: BillStatus.pending,
        memberStatuses: initialStatuses,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Create Bill',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_scannedItems == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Step $_step/2'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_scannedItems != null) ...[
          // Scanned items confirmation screen
          _buildScannedConfirmationScreen(),
        ] else if (_step == 1) ...[
          ReceiptScanCard(
            onTap: _isScanning ? null : _showScanOptions,
            isLoading: _isScanning,
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR MANUAL ENTRY',
                  style: TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Bill Title',
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => _title = value,
          ),
          const SizedBox(height: 12),
          Text(
            'Who paid?',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final user in widget.users)
                ChoiceChip(
                  label: Text(user.name),
                  selected: _payerId == user.id,
                  onSelected: (_) => setState(() => _payerId = user.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Currency',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final curr in billCurrencies.keys)
                ChoiceChip(
                  label: Text(curr),
                  selected: _currency == curr,
                  onSelected: (_) => setState(() => _currency = curr),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'SST (%)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _sst = double.tryParse(value) ?? _sst,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Service (%)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) =>
                          _serviceCharge =
                              double.tryParse(value) ?? _serviceCharge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('Next: Add Items'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.isEmpty ? 'New Bill' : _title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Paid by: ${widget.users.firstWhere((u) => u.id == _payerId).name}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                Text(
                  '${billCurrencies[_currency]!.symbol} ${_calculateTotal().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            EmptyState(
              message: 'Add your first item',
              actionLabel: 'Add Item',
              onAction: _addItem,
            )
          else
            ..._items.map(
              (item) => BillItemEditor(
                item: item,
                users: widget.users,
                currencySymbol: billCurrencies[_currency]!.symbol,
                onChanged: _updateItem,
                nameController: _nameControllers[item.id]!,
                priceController: _priceControllers[item.id]!,
                onRemove: () {
                  setState(() {
                    _items.remove(item);
                  });
                  _nameControllers.remove(item.id)?.dispose();
                  _priceControllers.remove(item.id)?.dispose();
                },
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saveBill,
                  child: const Text('Save Bill'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class BillDetailsView extends StatefulWidget {
  const BillDetailsView({
    required this.bill,
    required this.users,
    required this.onClose,
    required this.onUpdate,
    super.key,
  });

  final BillModel bill;
  final List<BillUser> users;
  final VoidCallback onClose;
  final ValueChanged<BillModel> onUpdate;

  @override
  State<BillDetailsView> createState() => _BillDetailsViewState();
}

class _BillDetailsViewState extends State<BillDetailsView> {
  String? _expandedUserId;

  @override
  Widget build(BuildContext context) {
    final payer = widget.users.firstWhere((u) => u.id == widget.bill.payerId);
    final splits = calculateUserSplits(widget.bill, widget.users);
    final currency = billCurrencies[widget.bill.currency]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bill.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Paid by ${payer.name}'),
              ],
            ),
            FilledButton(
              onPressed: () {
                final nextStatus =
                    widget.bill.status == BillStatus.settled
                        ? BillStatus.pending
                        : BillStatus.settled;
                widget.onUpdate(
                  BillModel(
                    id: widget.bill.id,
                    groupId: widget.bill.groupId,
                    title: widget.bill.title,
                    date: widget.bill.date,
                    totalAmount: widget.bill.totalAmount,
                    currency: widget.bill.currency,
                    exchangeRate: widget.bill.exchangeRate,
                    items: widget.bill.items,
                    sst: widget.bill.sst,
                    serviceCharge: widget.bill.serviceCharge,
                    payerId: widget.bill.payerId,
                    status: nextStatus,
                    memberStatuses: widget.bill.memberStatuses,
                  ),
                );
              },
              child: Text(
                widget.bill.status == BillStatus.settled
                    ? 'Settled'
                    : 'Pending',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Text('Total Bill', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                '${currency.symbol} ${widget.bill.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.bill.currency != 'MYR')
                Text(
                  '≈ RM ${(widget.bill.totalAmount * widget.bill.exchangeRate).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Split Breakdown',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              for (final user in widget.users)
                UserSplitTile(
                  user: user,
                  bill: widget.bill,
                  split: splits[user.id],
                  currency: currency,
                  expanded: _expandedUserId == user.id,
                  onToggle:
                      () => setState(() {
                        _expandedUserId =
                            _expandedUserId == user.id ? null : user.id;
                      }),
                  onToggleStatus: () {
                    final current =
                        widget.bill.memberStatuses[user.id] ??
                        BillStatus.pending;
                    final updated = Map<String, BillStatus>.from(
                      widget.bill.memberStatuses,
                    );
                    updated[user.id] =
                        current == BillStatus.settled
                            ? BillStatus.pending
                            : BillStatus.settled;
                    widget.onUpdate(
                      BillModel(
                        id: widget.bill.id,
                        groupId: widget.bill.groupId,
                        title: widget.bill.title,
                        date: widget.bill.date,
                        totalAmount: widget.bill.totalAmount,
                        currency: widget.bill.currency,
                        exchangeRate: widget.bill.exchangeRate,
                        items: widget.bill.items,
                        sst: widget.bill.sst,
                        serviceCharge: widget.bill.serviceCharge,
                        payerId: widget.bill.payerId,
                        status: widget.bill.status,
                        memberStatuses: updated,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.onClose,
          child: const Text('Close Details'),
        ),
      ],
    );
  }
}
