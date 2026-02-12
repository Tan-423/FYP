import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    required this.onSettleUp,
    required this.onViewBill,
    super.key,
  });

  final BillGroup group;
  final List<BillGroup> groups;
  final List<BillModel> bills;
  final ValueChanged<String> onSwitchGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onNewBill;
  final VoidCallback onSettleUp;
  final ValueChanged<BillModel> onViewBill;

  @override
  Widget build(BuildContext context) {
    final memberTotals = <BillUser, double>{
      for (final member in group.members) member: 0,
    };

    for (final bill in bills) {
      final splits = calculateUserSplits(bill, group.members);
      for (final entry in splits.entries) {
        final member = group.members.firstWhere(
          (m) => m.id == entry.key,
          orElse: () {
            return group.members.first;
          },
        );
        if (!memberTotals.containsKey(member)) continue;
        memberTotals[member] =
            (memberTotals[member] ?? 0) +
            (entry.value.total * bill.exchangeRate);
      }
    }

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
          memberTotals: memberTotals,
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
            Expanded(
              child: QuickActionCard(
                title: 'Settle Up',
                subtitle: 'Clear debts',
                icon: Icons.refresh_rounded,
                color: const Color(0xFF10B981),
                onTap: onSettleUp,
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
    required this.ownerId,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final String ownerId;
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
    
    // Validate that name doesn't contain digits
    if (RegExp(r'\d').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member name cannot contain digits'),
        ),
      );
      return;
    }
    
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
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\d')),
                ],
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
                      ownerId: widget.ownerId,
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
    required this.ownerId,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final List<BillUser> users;
  final String activeGroupId;
  final String ownerId;
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
  final TextEditingController _sstController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
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
    _sstController.text = _sst.toString();
    _serviceController.text = _serviceCharge.toString();
  }

  @override
  void dispose() {
    _sstController.dispose();
    _serviceController.dispose();
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _getRateForCurrency(String currency) {
    return billCurrencies[currency]!.rate;
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
    final itemsFromBlocks = _parseReceiptItemsFromBlocks(recognized);
    if (itemsFromBlocks.isNotEmpty) {
      return itemsFromBlocks;
    }
    return _parseReceiptItems(recognized.text);
  }

  List<BillItem> _parseReceiptItemsFromBlocks(RecognizedText recognized) {
    final items = <BillItem>[];
    final pricePattern = RegExp(r'(\d+[\.,]\d{2})');
    final qtyPattern = RegExp(r'^\s*\d+\s+');
    final lines = <_OcrLine>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        lines.add(_OcrLine(text: text, box: line.boundingBox));
      }
    }

    if (lines.isEmpty) return items;

    lines.sort((a, b) {
      final dy = (a.centerY - b.centerY).abs();
      if (dy < 6) {
        return a.left.compareTo(b.left);
      }
      return a.centerY.compareTo(b.centerY);
    });

    final nameCandidates = <_OcrLine>[];

    for (final line in lines) {
      final trimmed = line.text;
      final lower = trimmed.toLowerCase();
      final matches = pricePattern.allMatches(trimmed);

      if (matches.isEmpty) {
        if (_isIgnoredLine(lower)) {
          nameCandidates.clear();
          continue;
        }
        if (_isHeaderLine(lower)) {
          continue;
        }
        if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) && trimmed.length > 1) {
          final candidate = _cleanCandidateName(trimmed);
          if (candidate.isNotEmpty && candidate.length > 1) {
            nameCandidates.add(line.copyWith(text: candidate));
            if (nameCandidates.length > 4) {
              nameCandidates.removeAt(0);
            }
          }
        }
        continue;
      }

      final lastMatch = matches.last;
      final priceStr = lastMatch.group(1)!.replaceAll(',', '.');
      final amount = double.tryParse(priceStr) ?? 0;
      if (amount <= 0) {
        nameCandidates.clear();
        continue;
      }

      var textBeforePrice = trimmed.substring(0, lastMatch.start).trim();
      textBeforePrice = textBeforePrice.replaceAll(
        RegExp(r'\s+(RM|MYR|rm)\s*$', caseSensitive: false),
        '',
      );
      textBeforePrice = textBeforePrice.replaceAll(qtyPattern, '');
      textBeforePrice = textBeforePrice.replaceAll(
        RegExp(r'^\d+[\.\)]\s*'),
        '',
      );
      textBeforePrice = textBeforePrice.replaceAll(RegExp(r'\s{2,}'), ' ');
      textBeforePrice = textBeforePrice.trim();

      String name = _cleanCandidateName(textBeforePrice);

      final lineHeight = line.height > 0 ? line.height : 18;
      final rowThreshold = (lineHeight * 0.7).clamp(10, 28);
      final sameRowCandidates =
          nameCandidates.where((candidate) {
            final sameRow =
                (candidate.centerY - line.centerY).abs() <= rowThreshold;
            final isLeftOfPrice = candidate.right <= line.left + 6;
            return sameRow && isLeftOfPrice;
          }).toList();

      if (name.length < 3 || !RegExp(r'[a-zA-Z]{2,}').hasMatch(name)) {
        if (sameRowCandidates.isNotEmpty) {
          name = sameRowCandidates.last.text;
        } else if (nameCandidates.isNotEmpty) {
          final nearestAbove = nameCandidates.reversed.firstWhere(
            (candidate) => candidate.centerY < line.centerY,
            orElse: () => nameCandidates.last,
          );
          if ((line.centerY - nearestAbove.centerY) <= lineHeight * 3) {
            name = nearestAbove.text;
          }
        }
      }

      nameCandidates.clear();

      if (name.isEmpty || name.length < 2) {
        name = 'Item ${items.length + 1}';
      }

      name = name.replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '').trim();
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
    }

    return items;
  }

  List<BillItem> _parseReceiptItems(String rawText) {
    final lines = rawText.split('\n');
    final items = <BillItem>[];
    final pricePattern = RegExp(r'(\d+[\.,]\d{2})');
    final qtyPattern = RegExp(r'^\s*\d+\s+'); // Pattern for leading quantity
    final List<String> candidateNames = [];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      // Look for any price in the line
      final matches = pricePattern.allMatches(trimmed);
      if (matches.isEmpty) {
        // Skip ignored or header-only lines
        if (_isIgnoredLine(lower)) {
          candidateNames.clear();
          continue;
        }
        if (_isHeaderLine(lower)) {
          continue;
        }

        // No price, save as potential item name if it has letters
        if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) && trimmed.length > 1) {
          final candidate = _cleanCandidateName(trimmed);
          if (candidate.isNotEmpty && candidate.length > 1) {
            candidateNames.add(candidate);
            if (candidateNames.length > 3) {
              candidateNames.removeAt(0);
            }
          }
        }
        continue;
      }

      // Found price(s), use the last one as the item price
      final lastMatch = matches.last;
      final priceStr = lastMatch.group(1)!.replaceAll(',', '.');
      final amount = double.tryParse(priceStr) ?? 0;
      if (amount <= 0) {
        candidateNames.clear();
        continue;
      }

      // Try to extract name from the same line first
      var textBeforePrice = trimmed.substring(0, lastMatch.start).trim();

      // Clean up the text before price
      textBeforePrice = textBeforePrice.replaceAll(
        RegExp(r'\s+(RM|MYR|rm)\s*$', caseSensitive: false),
        '',
      );
      textBeforePrice = textBeforePrice.replaceAll(qtyPattern, '');
      textBeforePrice = textBeforePrice.replaceAll(
        RegExp(r'^\d+[\.\)]\s*'),
        '',
      );
      textBeforePrice = textBeforePrice.replaceAll(RegExp(r'\s{2,}'), ' ');
      textBeforePrice = textBeforePrice.trim();

      String name = _cleanCandidateName(textBeforePrice);

      // If name is too short or mostly numbers, look for better candidates
      if (name.length < 3 || !RegExp(r'[a-zA-Z]{2,}').hasMatch(name)) {
        if (candidateNames.isNotEmpty) {
          for (var j = candidateNames.length - 1; j >= 0; j--) {
            final candidate = candidateNames[j];
            if (candidate.length >= 2 &&
                RegExp(r'[a-zA-Z]').hasMatch(candidate)) {
              name = candidate;
              break;
            }
          }
        }
      }

      // Clear candidates after use to avoid reusing old names
      candidateNames.clear();

      // If still no valid name, create a placeholder
      if (name.isEmpty || name.length < 2) {
        name = 'Item ${items.length + 1}';
      }

      // Final cleanup: remove trailing/leading special characters
      name = name.replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '');
      name = name.trim();

      // Ensure name is not empty after cleanup
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
    }

    return items;
  }

  String _cleanCandidateName(String value) {
    var candidate = value;
    candidate = candidate.replaceAll(RegExp(r'^[-*•]\s*'), '');
    candidate = candidate.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');
    candidate = candidate.replaceAll(RegExp(r'\s{2,}'), ' ');
    candidate = candidate.trim();
    return candidate;
  }

  bool _isHeaderLine(String text) {
    const headerKeywords = [
      'item',
      'description',
      'qty',
      'quantity',
      'price',
      'amount',
      'product',
      'name',
      'ticket id',
      'ticket',
    ];
    for (final keyword in headerKeywords) {
      if (text.contains(keyword) && text.length < 40) {
        return true;
      }
    }
    return false;
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
    if (!_validateStepOne()) return;
    if (!_validateItems(_scannedItems!)) return;

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
                onSelected:
                    (_) => setState(() {
                      _currency = curr;
                    }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Rate: 1 $_currency = RM ${_getRateForCurrency(_currency).toStringAsFixed(4)}',
          style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                controller: _sstController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
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
                controller: _serviceController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
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

  bool _validateStepOne() {
    if (_title.trim().isEmpty) {
      _showSnackBar('Please enter a bill title.');
      return false;
    }
    if (_sstController.text.trim().isEmpty ||
        _serviceController.text.trim().isEmpty) {
      _showSnackBar('Please fill SST and Service fields.');
      return false;
    }
    return true;
  }

  bool _validateItems(List<BillItem> items) {
    for (final item in items) {
      if (item.name.trim().isEmpty) {
        _showSnackBar('Please fill all item names.');
        return false;
      }
      if (item.price <= 0) {
        _showSnackBar('Please enter valid item prices.');
        return false;
      }
    }
    return true;
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
    if (!_validateStepOne()) return;
    if (_items.isEmpty) {
      _showSnackBar('Please add at least one item.');
      return;
    }
    if (!_validateItems(_items)) return;
    final initialStatuses = <String, BillStatus>{};
    for (final user in widget.users) {
      initialStatuses[user.id] =
          user.id == _payerId ? BillStatus.settled : BillStatus.pending;
    }

    final exchangeRate =
        _getRateForCurrency(_currency) / billCurrencies['MYR']!.rate;

    widget.onSave(
      BillModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        groupId: widget.activeGroupId,
        ownerId: widget.ownerId,
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
                  onSelected:
                      (_) => setState(() {
                        _currency = curr;
                      }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Rate: 1 $_currency = RM ${_getRateForCurrency(_currency).toStringAsFixed(4)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                  controller: _sstController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
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
                  controller: _serviceController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
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
            onPressed: () {
              if (!_validateStepOne()) return;
              setState(() => _step = 2);
            },
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
    required this.onDelete,
    super.key,
  });

  final BillModel bill;
  final List<BillUser> users;
  final VoidCallback onClose;
  final Future<void> Function(BillModel) onUpdate;
  final Future<void> Function(BillModel) onDelete;

  @override
  State<BillDetailsView> createState() => _BillDetailsViewState();
}

class _BillDetailsViewState extends State<BillDetailsView> {
  String? _expandedUserId;
  bool _isEditing = false;
  TextEditingController? _titleController;
  TextEditingController? _sstController;
  TextEditingController? _serviceController;
  late double _editSst;
  late double _editServiceCharge;
  List<BillItem> _editItems = [];
  final Map<String, TextEditingController> _editNameControllers = {};
  final Map<String, TextEditingController> _editPriceControllers = {};

  @override
  void initState() {
    super.initState();
    _syncEditFields(widget.bill);
  }

  @override
  void didUpdateWidget(BillDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.bill.id != widget.bill.id) {
      _syncEditFields(widget.bill);
    }
  }

  @override
  void dispose() {
    _titleController?.dispose();
    _sstController?.dispose();
    _serviceController?.dispose();
    for (final controller in _editNameControllers.values) {
      controller.dispose();
    }
    for (final controller in _editPriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncEditFields(BillModel bill) {
    _titleController?.dispose();
    _sstController?.dispose();
    _serviceController?.dispose();

    _titleController = TextEditingController(text: bill.title);
    _sstController = TextEditingController(text: bill.sst.toString());
    _serviceController = TextEditingController(
      text: bill.serviceCharge.toString(),
    );
    _editSst = bill.sst;
    _editServiceCharge = bill.serviceCharge;
    _editItems =
        bill.items
            .map(
              (item) => BillItem(
                id: item.id,
                name: item.name,
                price: item.price,
                assignedTo: List<String>.from(item.assignedTo),
              ),
            )
            .toList();

    for (final controller in _editNameControllers.values) {
      controller.dispose();
    }
    for (final controller in _editPriceControllers.values) {
      controller.dispose();
    }
    _editNameControllers.clear();
    _editPriceControllers.clear();
    for (final item in _editItems) {
      _editNameControllers[item.id] = TextEditingController(text: item.name);
      _editPriceControllers[item.id] = TextEditingController(
        text: item.price.toStringAsFixed(2),
      );
    }
  }

  void _startEdit() {
    setState(() {
      _syncEditFields(widget.bill);
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _syncEditFields(widget.bill);
      _isEditing = false;
    });
  }

  void _addEditItem() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _editItems.add(
        BillItem(
          id: id,
          name: '',
          price: 0,
          assignedTo: widget.users.map((u) => u.id).toList(),
        ),
      );
      _editNameControllers[id] = TextEditingController();
      _editPriceControllers[id] = TextEditingController(text: '0');
    });
  }

  void _updateEditItem(
    String itemId, {
    String? name,
    double? price,
    List<String>? assignedTo,
  }) {
    setState(() {
      for (var i = 0; i < _editItems.length; i++) {
        if (_editItems[i].id == itemId) {
          _editItems[i] = BillItem(
            id: _editItems[i].id,
            name: name ?? _editItems[i].name,
            price: price ?? _editItems[i].price,
            assignedTo: assignedTo ?? _editItems[i].assignedTo,
          );
        }
      }
    });
  }

  double _calculateEditTotal() {
    final subtotal = _editItems.fold<double>(
      0,
      (acc, item) => acc + item.price,
    );
    final tax = subtotal * (_editSst / 100);
    final svc = subtotal * (_editServiceCharge / 100);
    return subtotal + tax + svc;
  }

  Future<void> _saveEdits() async {
    if (!_validateEditFields()) return;
    if (!_validateEditItems()) return;
    final title = _titleController?.text.trim() ?? '';
    final updated = BillModel(
      id: widget.bill.id,
      groupId: widget.bill.groupId,
      ownerId: widget.bill.ownerId,
      title: title.isEmpty ? widget.bill.title : title,
      date: widget.bill.date,
      totalAmount: _calculateEditTotal(),
      currency: widget.bill.currency,
      exchangeRate: widget.bill.exchangeRate,
      items: List<BillItem>.from(_editItems),
      sst: _editSst,
      serviceCharge: _editServiceCharge,
      payerId: widget.bill.payerId,
      status: widget.bill.status,
      memberStatuses: widget.bill.memberStatuses,
    );
    await widget.onUpdate(updated);
    if (!mounted) return;
    setState(() => _isEditing = false);
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Bill'),
            content: const Text(
              'Are you sure you want to delete this bill? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (shouldDelete != true) return;
    await widget.onDelete(widget.bill);
  }

  bool _allMembersSettled(Map<String, BillStatus> statuses) {
    if (statuses.isEmpty) return false;
    return statuses.values.every((status) => status == BillStatus.settled);
  }

  bool _validateEditFields() {
    final title = _titleController?.text.trim() ?? '';
    if (title.isEmpty) {
      _showSnackBar('Please enter a bill title.');
      return false;
    }
    if (_sstController?.text.trim().isEmpty ?? true) {
      _showSnackBar('Please enter SST.');
      return false;
    }
    if (_serviceController?.text.trim().isEmpty ?? true) {
      _showSnackBar('Please enter service charge.');
      return false;
    }
    return true;
  }

  bool _validateEditItems() {
    if (_editItems.isEmpty) {
      _showSnackBar('Please add at least one item.');
      return false;
    }
    for (final item in _editItems) {
      if (item.name.trim().isEmpty) {
        _showSnackBar('Please fill all item names.');
        return false;
      }
      if (item.price <= 0) {
        _showSnackBar('Please enter valid item prices.');
        return false;
      }
    }
    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final payer = widget.users.firstWhere((u) => u.id == bill.payerId);
    final splits = calculateUserSplits(bill, widget.users);
    final currency = billCurrencies[bill.currency]!;
    final totalAmount = _isEditing ? _calculateEditTotal() : bill.totalAmount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Bill' : bill.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Paid by ${payer.name}'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_isEditing)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveEdits,
                    child: const Text('Save'),
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _startEdit,
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit bill',
                  ),
                  IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete bill',
                  ),
                  FilledButton(
                    onPressed: () async {
                      final nextStatus =
                          bill.status == BillStatus.settled
                              ? BillStatus.pending
                              : BillStatus.settled;
                      if (nextStatus == BillStatus.settled &&
                          !_allMembersSettled(bill.memberStatuses)) {
                        _showSnackBar(
                          'Cannot mark bill as settled until all members are settled.',
                        );
                        return;
                      }
                      await widget.onUpdate(
                        BillModel(
                          id: bill.id,
                          groupId: bill.groupId,
                          ownerId: bill.ownerId,
                          title: bill.title,
                          date: bill.date,
                          totalAmount: bill.totalAmount,
                          currency: bill.currency,
                          exchangeRate: bill.exchangeRate,
                          items: bill.items,
                          sst: bill.sst,
                          serviceCharge: bill.serviceCharge,
                          payerId: bill.payerId,
                          status: nextStatus,
                          memberStatuses: bill.memberStatuses,
                        ),
                      );
                    },
                    child: Text(
                      bill.status == BillStatus.settled ? 'Settled' : 'Pending',
                    ),
                  ),
                ],
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
                '${currency.symbol} ${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (bill.currency != 'MYR')
                Text(
                  '≈ RM ${(totalAmount * bill.exchangeRate).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _titleController!,
            decoration: const InputDecoration(
              labelText: 'Bill Title',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Currency',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${bill.currency} • Rate 1 ${bill.currency} = RM ${bill.exchangeRate.toStringAsFixed(4)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sstController,
                  decoration: const InputDecoration(
                    labelText: 'SST (%)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged:
                      (value) => _editSst = double.tryParse(value) ?? _editSst,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Service (%)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged:
                      (value) =>
                          _editServiceCharge =
                              double.tryParse(value) ?? _editServiceCharge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_editItems.isEmpty)
            EmptyState(
              message: 'Add your first item',
              actionLabel: 'Add Item',
              onAction: _addEditItem,
            )
          else
            ..._editItems.map(
              (item) => BillItemEditor(
                item: item,
                users: widget.users,
                currencySymbol: currency.symbol,
                onChanged: _updateEditItem,
                nameController: _editNameControllers[item.id]!,
                priceController: _editPriceControllers[item.id]!,
                onRemove: () {
                  setState(() {
                    _editItems.remove(item);
                  });
                  _editNameControllers.remove(item.id)?.dispose();
                  _editPriceControllers.remove(item.id)?.dispose();
                },
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addEditItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
          ),
        ] else ...[
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
                    bill: bill,
                    split: splits[user.id],
                    currency: currency,
                    expanded: _expandedUserId == user.id,
                    onToggle:
                        () => setState(() {
                          _expandedUserId =
                              _expandedUserId == user.id ? null : user.id;
                        }),
                    onToggleStatus: () async {
                      final current =
                          bill.memberStatuses[user.id] ?? BillStatus.pending;
                      final updated = Map<String, BillStatus>.from(
                        bill.memberStatuses,
                      );
                      updated[user.id] =
                          current == BillStatus.settled
                              ? BillStatus.pending
                              : BillStatus.settled;
                      final nextBillStatus =
                          _allMembersSettled(updated)
                              ? BillStatus.settled
                              : BillStatus.pending;
                      await widget.onUpdate(
                        BillModel(
                          id: bill.id,
                          groupId: bill.groupId,
                          ownerId: bill.ownerId,
                          title: bill.title,
                          date: bill.date,
                          totalAmount: bill.totalAmount,
                          currency: bill.currency,
                          exchangeRate: bill.exchangeRate,
                          items: bill.items,
                          sst: bill.sst,
                          serviceCharge: bill.serviceCharge,
                          payerId: bill.payerId,
                          status: nextBillStatus,
                          memberStatuses: updated,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.onClose,
          child: const Text('Close Details'),
        ),
      ],
    );
  }
}

class _OcrLine {
  _OcrLine({required this.text, required this.box});

  final String text;
  final Rect box;

  double get left => box.left;
  double get right => box.right;
  double get centerY => box.center.dy;
  double get height => box.height;

  _OcrLine copyWith({String? text}) {
    return _OcrLine(text: text ?? this.text, box: box);
  }
}
