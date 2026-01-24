import 'package:flutter/material.dart';

class BillTrackingScreen extends StatefulWidget {
  const BillTrackingScreen({super.key});

  @override
  State<BillTrackingScreen> createState() => _BillTrackingScreenState();
}

class _BillTrackingScreenState extends State<BillTrackingScreen> {
  BillTrackingView _view = BillTrackingView.dashboard;
  String _activeGroupId = 'g1';
  BillModel? _selectedBill;

  final List<BillGroup> _groups = [
    BillGroup(
      id: 'g1',
      name: 'Trip to Penang',
      members: _mockUsers,
    ),
  ];

  late List<BillModel> _bills = [
    BillModel(
      id: 'b1',
      groupId: 'g1',
      title: 'Lunch at Nasi Kandar Pelita',
      date: DateTime(2025, 10, 24),
      totalAmount: 51.94,
      currency: 'MYR',
      exchangeRate: 1,
      items: [
        BillItem(
          id: 'i1',
          name: 'Nasi Kandar (Me)',
          price: 15,
          assignedTo: ['u1'],
        ),
        BillItem(
          id: 'i2',
          name: 'Fried Chicken (Ali)',
          price: 12,
          assignedTo: ['u2'],
        ),
        BillItem(
          id: 'i3',
          name: 'Drinks (Shared)',
          price: 18.5,
          assignedTo: ['u1', 'u2'],
        ),
      ],
      sst: 6,
      serviceCharge: 10,
      payerId: 'u1',
      status: BillStatus.pending,
      memberStatuses: {
        'u1': BillStatus.settled,
        'u2': BillStatus.pending,
        'u3': BillStatus.pending,
        'u4': BillStatus.pending,
      },
    ),
    BillModel(
      id: 'b2',
      groupId: 'g1',
      title: 'Grab to Airport',
      date: DateTime(2025, 10, 25),
      totalAmount: 65,
      currency: 'MYR',
      exchangeRate: 1,
      items: [
        BillItem(
          id: 'i1',
          name: 'Ride Fare',
          price: 65,
          assignedTo: ['u1', 'u2', 'u3', 'u4'],
        ),
      ],
      sst: 0,
      serviceCharge: 0,
      payerId: 'u2',
      status: BillStatus.pending,
      memberStatuses: {
        'u1': BillStatus.pending,
        'u2': BillStatus.settled,
        'u3': BillStatus.pending,
        'u4': BillStatus.pending,
      },
    ),
  ];

  BillGroup get _activeGroup =>
      _groups.firstWhere((g) => g.id == _activeGroupId);

  List<BillModel> get _activeBills =>
      _bills.where((b) => b.groupId == _activeGroupId).toList();

  void _updateBill(BillModel bill) {
    setState(() {
      _bills = _bills.map((b) => b.id == bill.id ? bill : b).toList();
      if (_selectedBill?.id == bill.id) {
        _selectedBill = bill;
      }
    });
  }

  void _createGroup(BillGroup group) {
    setState(() {
      _groups.add(group);
      _activeGroupId = group.id;
      _view = BillTrackingView.dashboard;
    });
  }

  void _createBill(BillModel bill) {
    setState(() {
      _bills = [bill, ..._bills];
      _view = BillTrackingView.dashboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Bill Tracking'),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildBody(),
      ),
      floatingActionButton: _view == BillTrackingView.dashboard
          ? FloatingActionButton(
              onPressed: () =>
                  setState(() => _view = BillTrackingView.createBill),
              backgroundColor: const Color(0xFF2563EB),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _view == BillTrackingView.dashboard ||
              _view == BillTrackingView.history
          ? NavigationBar(
              selectedIndex: _view == BillTrackingView.dashboard ? 0 : 1,
              onDestinationSelected: (index) {
                setState(() {
                  _view = index == 0
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
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case BillTrackingView.dashboard:
        return BillDashboard(
          group: _activeGroup,
          groups: _groups,
          bills: _activeBills,
          onSwitchGroup: (id) => setState(() => _activeGroupId = id),
          onCreateGroup: () =>
              setState(() => _view = BillTrackingView.createGroup),
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
          onCancel: () =>
              setState(() => _view = BillTrackingView.dashboard),
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
        return BillCreateBill(
          users: _activeGroup.members,
          activeGroupId: _activeGroup.id,
          onSave: _createBill,
          onCancel: () =>
              setState(() => _view = BillTrackingView.dashboard),
        );
      case BillTrackingView.details:
        return BillDetailsView(
          bill: _selectedBill!,
          users: _activeGroup.members,
          onClose: () =>
              setState(() => _view = BillTrackingView.dashboard),
          onUpdate: _updateBill,
        );
    }
  }
}

enum BillTrackingView { dashboard, createBill, details, history, createGroup }

class BillUser {
  const BillUser({required this.id, required this.name, required this.avatarUrl});
  final String id;
  final String name;
  final String avatarUrl;
}

class BillGroup {
  const BillGroup({required this.id, required this.name, required this.members});
  final String id;
  final String name;
  final List<BillUser> members;
}

class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.price,
    required this.assignedTo,
  });

  final String id;
  final String name;
  final double price;
  final List<String> assignedTo;
}

enum BillStatus { settled, pending }

class BillModel {
  const BillModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.date,
    required this.totalAmount,
    required this.currency,
    required this.exchangeRate,
    required this.items,
    required this.sst,
    required this.serviceCharge,
    required this.payerId,
    required this.status,
    required this.memberStatuses,
  });

  final String id;
  final String groupId;
  final String title;
  final DateTime date;
  final double totalAmount;
  final String currency;
  final double exchangeRate;
  final List<BillItem> items;
  final double sst;
  final double serviceCharge;
  final String payerId;
  final BillStatus status;
  final Map<String, BillStatus> memberStatuses;
}

class CurrencyInfo {
  const CurrencyInfo({
    required this.rate,
    required this.symbol,
    required this.name,
  });
  final double rate;
  final String symbol;
  final String name;
}

const Map<String, CurrencyInfo> _billCurrencies = {
  'MYR': CurrencyInfo(rate: 1, symbol: 'RM', name: 'Ringgit Malaysia'),
  'SGD': CurrencyInfo(rate: 3.5, symbol: 'S\$', name: 'Singapore Dollar'),
  'USD': CurrencyInfo(rate: 4.7, symbol: '\$', name: 'US Dollar'),
  'THB': CurrencyInfo(rate: 0.13, symbol: 'THB', name: 'Thai Baht'),
  'JPY': CurrencyInfo(rate: 0.03, symbol: 'JPY', name: 'Japanese Yen'),
};

const List<BillUser> _mockUsers = [
  BillUser(
    id: 'u1',
    name: 'Me',
    avatarUrl: 'https://i.pravatar.cc/150?u=Me',
  ),
  BillUser(
    id: 'u2',
    name: 'Ali',
    avatarUrl: 'https://i.pravatar.cc/150?u=Ali',
  ),
  BillUser(
    id: 'u3',
    name: 'Siti',
    avatarUrl: 'https://i.pravatar.cc/150?u=Siti',
  ),
  BillUser(
    id: 'u4',
    name: 'John',
    avatarUrl: 'https://i.pravatar.cc/150?u=John',
  ),
];

class UserSplit {
  UserSplit({required this.subtotal, required this.total, required this.items});

  double subtotal;
  double total;
  final List<SplitItem> items;
}

class SplitItem {
  SplitItem({required this.name, required this.share});

  final String name;
  final double share;
}

Map<String, UserSplit> calculateUserSplits(
  BillModel bill,
  List<BillUser> users,
) {
  final splits = <String, UserSplit>{};
  for (final user in users) {
    splits[user.id] = UserSplit(subtotal: 0, total: 0, items: []);
  }

  for (final item in bill.items) {
    if (item.assignedTo.isEmpty) continue;
    final share = item.price / item.assignedTo.length;
    for (final userId in item.assignedTo) {
      final split = splits[userId];
      if (split != null) {
        split.subtotal += share;
        split.items.add(SplitItem(name: item.name, share: share));
      }
    }
  }

  final taxMultiplier = 1 + ((bill.sst + bill.serviceCharge) / 100);
  for (final entry in splits.entries) {
    entry.value.total = entry.value.subtotal * taxMultiplier;
  }

  return splits;
}

class BillDashboard extends StatelessWidget {
  const BillDashboard({
    super.key,
    required this.group,
    required this.groups,
    required this.bills,
    required this.onSwitchGroup,
    required this.onCreateGroup,
    required this.onNewBill,
    required this.onViewBill,
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
    final myTotalOwe = bills.fold<double>(0, (acc, bill) {
      if (bill.payerId == 'u1') return acc;
      if (bill.memberStatuses['u1'] == BillStatus.settled) return acc;
      final splits = calculateUserSplits(bill, group.members);
      return acc + (splits['u1']?.total ?? 0) * bill.exchangeRate;
    });

    final totalSpent = bills.fold<double>(
      0,
      (acc, bill) => acc + (bill.totalAmount * bill.exchangeRate),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _BillGroupSelector(
          group: group,
          groups: groups,
          onSwitchGroup: onSwitchGroup,
          onCreateGroup: onCreateGroup,
        ),
        const SizedBox(height: 16),
        _BillSummaryCard(
          totalSpent: totalSpent,
          myTotalOwe: myTotalOwe,
          settledCount: bills.where((b) => b.status == BillStatus.settled).length,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Scan Bill',
                subtitle: 'AI auto-split',
                icon: Icons.photo_camera_rounded,
                color: const Color(0xFF2563EB),
                onTap: onNewBill,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _QuickActionCard(
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(onPressed: onNewBill, child: const Text('New Bill')),
          ],
        ),
        const SizedBox(height: 8),
        if (bills.isEmpty)
          _EmptyState(
            message: 'No bills in this group yet.',
            actionLabel: 'Create First Bill',
            onAction: onNewBill,
          )
        else
          ...bills.take(3).map(
                (bill) => BillListItem(
                  bill: bill,
                  onTap: () => onViewBill(bill),
                ),
              ),
      ],
    );
  }
}

class _BillGroupSelector extends StatefulWidget {
  const _BillGroupSelector({
    required this.group,
    required this.groups,
    required this.onSwitchGroup,
    required this.onCreateGroup,
  });

  final BillGroup group;
  final List<BillGroup> groups;
  final ValueChanged<String> onSwitchGroup;
  final VoidCallback onCreateGroup;

  @override
  State<_BillGroupSelector> createState() => _BillGroupSelectorState();
}

class _BillGroupSelectorState extends State<_BillGroupSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.groups_rounded, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Group',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.black54,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        widget.group.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final group in widget.groups)
                  ListTile(
                    title: Text(group.name),
                    trailing: widget.group.id == group.id
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF2563EB))
                        : null,
                    onTap: () {
                      widget.onSwitchGroup(group.id);
                      setState(() => _isExpanded = false);
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFF2563EB)),
                  title: const Text('Create New Group'),
                  onTap: () {
                    setState(() => _isExpanded = false);
                    widget.onCreateGroup();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BillSummaryCard extends StatelessWidget {
  const _BillSummaryCard({
    required this.totalSpent,
    required this.myTotalOwe,
    required this.settledCount,
  });

  final double totalSpent;
  final double myTotalOwe;
  final int settledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Group Spend (MYR)',
            style: TextStyle(color: Color(0xFFDBEAFE)),
          ),
          const SizedBox(height: 6),
          Text(
            'RM ${totalSpent.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BadgeChip(
                color: myTotalOwe > 0
                    ? const Color(0xFFF97316)
                    : const Color(0xFF22C55E),
                label: 'You owe: RM ${myTotalOwe.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              _BadgeChip(
                color: const Color(0xFF22C55E),
                label: 'Settled: $settledCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class BillHistoryView extends StatefulWidget {
  const BillHistoryView({super.key, required this.bills, required this.onViewBill});

  final List<BillModel> bills;
  final ValueChanged<BillModel> onViewBill;

  @override
  State<BillHistoryView> createState() => _BillHistoryViewState();
}

class _BillHistoryViewState extends State<BillHistoryView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.bills]
      ..sort((a, b) => b.date.compareTo(a.date));

    final filtered = sorted.where((bill) {
      if (_filter == 'All') return true;
      if (_filter == 'Settled') return bill.status == BillStatus.settled;
      if (_filter == 'Pending') return bill.status == BillStatus.pending;
      if (_filter == 'Paid by Me') return bill.payerId == 'u1';
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
              for (final label in ['All', 'Settled', 'Pending', 'Paid by Me'])
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
            (bill) => BillListItem(
              bill: bill,
              onTap: () => widget.onViewBill(bill),
            ),
          ),
      ],
    );
  }
}

class BillListItem extends StatelessWidget {
  const BillListItem({super.key, required this.bill, required this.onTap});

  final BillModel bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = bill.payerId == 'u1';
    final currency = _billCurrencies[bill.currency]!;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE2E8F0),
          child: Icon(
            Icons.receipt_long_rounded,
            color: isMe ? const Color(0xFF2563EB) : Colors.black54,
          ),
        ),
        title: Text(
          bill.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${bill.date.toIso8601String().split('T').first} • '
          '${isMe ? 'Paid by You' : 'Paid by Others'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${currency.symbol} ${bill.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _StatusPill(status: bill.status),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final isSettled = status == BillStatus.settled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSettled ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSettled ? 'Settled' : 'Pending',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSettled ? const Color(0xFF166534) : const Color(0xFF9A3412),
        ),
      ),
    );
  }
}

class BillCreateGroup extends StatefulWidget {
  const BillCreateGroup({super.key, required this.onSave, required this.onCancel});

  final ValueChanged<BillGroup> onSave;
  final VoidCallback onCancel;

  @override
  State<BillCreateGroup> createState() => _BillCreateGroupState();
}

class _BillCreateGroupState extends State<BillCreateGroup> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  final List<BillUser> _members = [
    _mockUsers.first,
  ];

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
    if (user.id == 'u1') return;
    setState(() => _members.remove(user));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'New Group',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                deleteIcon: member.id == 'u1'
                    ? null
                    : const Icon(Icons.close_rounded, size: 16),
                onDeleted: member.id == 'u1' ? null : () => _removeMember(member),
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
                  if (name.isEmpty) return;
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
    super.key,
    required this.users,
    required this.activeGroupId,
    required this.onSave,
    required this.onCancel,
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
  String _payerId = 'u1';
  double _sst = 6;
  double _serviceCharge = 10;
  final List<BillItem> _items = [];
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

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
        _billCurrencies['MYR']!.rate / _billCurrencies[_currency]!.rate;

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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Step $_step/2'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_step == 1) ...[
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final curr in _billCurrencies.keys)
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
                  onChanged: (value) =>
                      _sst = double.tryParse(value) ?? _sst,
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
                  onChanged: (value) =>
                      _serviceCharge = double.tryParse(value) ?? _serviceCharge,
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
                  '${_billCurrencies[_currency]!.symbol} ${_calculateTotal().toStringAsFixed(2)}',
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
            _EmptyState(
              message: 'Add your first item',
              actionLabel: 'Add Item',
              onAction: _addItem,
            )
          else
            ..._items.map(
              (item) => _BillItemEditor(
                item: item,
                users: widget.users,
                currencySymbol: _billCurrencies[_currency]!.symbol,
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

class _BillItemEditor extends StatelessWidget {
  const _BillItemEditor({
    required this.item,
    required this.users,
    required this.currencySymbol,
    required this.onChanged,
    required this.nameController,
    required this.priceController,
    required this.onRemove,
  });

  final BillItem item;
  final List<BillUser> users;
  final String currencySymbol;
  final void Function(String itemId,
      {String? name, double? price, List<String>? assignedTo}) onChanged;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => onChanged(item.id, name: value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => onChanged(
                      item.id,
                      price: double.tryParse(value) ?? 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final user in users)
                    FilterChip(
                      label: Text(user.name),
                      selected: item.assignedTo.contains(user.id),
                      onSelected: (selected) {
                        final next = List<String>.from(item.assignedTo);
                        if (selected) {
                          next.add(user.id);
                        } else {
                          next.remove(user.id);
                        }
                        onChanged(item.id, assignedTo: next);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BillDetailsView extends StatefulWidget {
  const BillDetailsView({
    super.key,
    required this.bill,
    required this.users,
    required this.onClose,
    required this.onUpdate,
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
    final currency = _billCurrencies[widget.bill.currency]!;

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
                final nextStatus = widget.bill.status == BillStatus.settled
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
              const Text(
                'Total Bill',
                style: TextStyle(color: Colors.black54),
              ),
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                _UserSplitTile(
                  user: user,
                  bill: widget.bill,
                  split: splits[user.id],
                  currency: currency,
                  expanded: _expandedUserId == user.id,
                  onToggle: () => setState(() {
                    _expandedUserId =
                        _expandedUserId == user.id ? null : user.id;
                  }),
                  onToggleStatus: () {
                    final current =
                        widget.bill.memberStatuses[user.id] ?? BillStatus.pending;
                    final updated = Map<String, BillStatus>.from(
                      widget.bill.memberStatuses,
                    );
                    updated[user.id] =
                        current == BillStatus.settled ? BillStatus.pending : BillStatus.settled;
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

class _UserSplitTile extends StatelessWidget {
  const _UserSplitTile({
    required this.user,
    required this.bill,
    required this.split,
    required this.currency,
    required this.expanded,
    required this.onToggle,
    required this.onToggleStatus,
  });

  final BillUser user;
  final BillModel bill;
  final UserSplit? split;
  final CurrencyInfo currency;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final total = (split?.total ?? 0) * bill.exchangeRate;
    final isPayer = bill.payerId == user.id;
    final status = bill.memberStatuses[user.id] ?? BillStatus.pending;

    return Column(
      children: [
        ListTile(
          onTap: onToggle,
          leading: CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl)),
          title: Row(
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isPayer)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ],
          ),
          subtitle: Text(isPayer ? 'Paid full amount' : 'Owes share'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!isPayer)
                TextButton(
                  onPressed: onToggleStatus,
                  child: Text(
                    status == BillStatus.settled ? 'Settled' : 'Pending',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: split == null || split!.items.isEmpty
                ? const Text('No items assigned',
                    style: TextStyle(color: Colors.black54))
                : Column(
                    children: [
                      for (final item in split!.items)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(item.name)),
                            Text(
                              '${currency.symbol} ${item.share.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(
                            '${currency.symbol} ${split!.subtotal.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
