import 'package:flutter/material.dart';

import 'bill_tracking_models.dart';

class BillGroupSelector extends StatefulWidget {
  const BillGroupSelector({
    required this.group,
    required this.groups,
    required this.onSwitchGroup,
    required this.onCreateGroup,
    super.key,
  });

  final BillGroup group;
  final List<BillGroup> groups;
  final ValueChanged<String> onSwitchGroup;
  final VoidCallback onCreateGroup;

  @override
  State<BillGroupSelector> createState() => _BillGroupSelectorState();
}

class _BillGroupSelectorState extends State<BillGroupSelector> {
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
                    trailing:
                        widget.group.id == group.id
                            ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF2563EB),
                            )
                            : null,
                    onTap: () {
                      widget.onSwitchGroup(group.id);
                      setState(() => _isExpanded = false);
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
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

class BillSummaryCard extends StatelessWidget {
  const BillSummaryCard({
    required this.totalSpent,
    required this.myTotalOwe,
    required this.settledCount,
    super.key,
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
              BadgeChip(
                color:
                    myTotalOwe > 0
                        ? const Color(0xFFF97316)
                        : const Color(0xFF22C55E),
                label: 'You owe: RM ${myTotalOwe.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              BadgeChip(
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

class BadgeChip extends StatelessWidget {
  const BadgeChip({required this.color, required this.label, super.key});

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

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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

class ReceiptScanCard extends StatelessWidget {
  const ReceiptScanCard({
    required this.onTap,
    required this.isLoading,
    super.key,
  });

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B5BDB), Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    isLoading
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Scan Receipt (AI)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Auto-fill items instantly',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
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

class BillListItem extends StatelessWidget {
  const BillListItem({required this.bill, required this.onTap, super.key});

  final BillModel bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = bill.payerId == 'u1';
    final currency = billCurrencies[bill.currency]!;

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
            StatusPill(status: bill.status),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

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

class BillItemEditor extends StatelessWidget {
  const BillItemEditor({
    required this.item,
    required this.users,
    required this.currencySymbol,
    required this.onChanged,
    required this.nameController,
    required this.priceController,
    required this.onRemove,
    super.key,
  });

  final BillItem item;
  final List<BillUser> users;
  final String currencySymbol;
  final void Function(
    String itemId, {
    String? name,
    double? price,
    List<String>? assignedTo,
  })
  onChanged;
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
                    onChanged:
                        (value) => onChanged(
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

class UserSplitTile extends StatelessWidget {
  const UserSplitTile({
    required this.user,
    required this.bill,
    required this.split,
    required this.currency,
    required this.expanded,
    required this.onToggle,
    required this.onToggleStatus,
    super.key,
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
              Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isPayer)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
            child:
                split == null || split!.items.isEmpty
                    ? const Text(
                      'No items assigned',
                      style: TextStyle(color: Colors.black54),
                    )
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
