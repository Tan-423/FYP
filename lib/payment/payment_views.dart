part of 'payment_screen.dart';

class _Header extends StatelessWidget {
  const _Header({required this.canGoBack, required this.onBack});

  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF2563EB),
                size: 28,
              ),
              onPressed: onBack,
            ),
          const SizedBox(width: 6),
          const Text(
            'Payment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.activeTab, required this.onTabChanged});

  final String activeTab;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          label: 'Checkout',
          isActive: activeTab == 'payment',
          onTap: () => onTabChanged('payment'),
        ),
        const SizedBox(width: 12),
        _TabButton(
          label: 'History',
          isActive: activeTab == 'history',
          onTap: () => onTabChanged('history'),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                isActive
                    ? [
                      const BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF60A5FA),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSelectionView extends StatelessWidget {
  const _PaymentSelectionView({
    required this.bookings,
    required this.onPayNow,
    this.notice,
  });

  final List<BookingItem> bookings;
  final ValueChanged<BookingItem> onPayNow;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (notice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PENDING BOOKINGS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              '${bookings.length} items',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...bookings.map(
          (item) => _BookingCard(item: item, onPayNow: () => onPayNow(item)),
        ),
        const SizedBox(height: 24),
        _PaymentMethodCard(),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.item, required this.onPayNow});

  final BookingItem item;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final isRetry = item.canRetry;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.currency} ${item.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.date.isEmpty ? '-' : item.date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((item.status ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Status: ${item.status}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onPayNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: Icon(
                  isRetry
                      ? Icons.refresh_rounded
                      : Icons.arrow_right_alt_rounded,
                ),
                label: Text(
                  isRetry ? 'Try Again' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.verified_user_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Text(
                'SECURE GATEWAYS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFF3B82F6),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PayPal',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.radio_button_unchecked,
                  size: 18,
                  color: Color(0xFFCBD5F5),
                ),
                SizedBox(width: 8),
                Text(
                  'Credit or Debit Card',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.history,
    required this.totalSpent,
    required this.onViewReceipt,
    this.notice,
  });

  final List<TransactionItem> history;
  final double totalSpent;
  final ValueChanged<TransactionItem> onViewReceipt;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (notice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332563EB),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL TRANSACTION VALUE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFBFDBFE),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'MYR ${totalSpent.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.history_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Last 30 Days',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No transactions yet.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          ...history.map(
            (txn) => _HistoryCard(
              item: txn,
              onViewReceipt: () => onViewReceipt(txn),
            ),
          ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onViewReceipt});

  final TransactionItem item;
  final VoidCallback onViewReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF2FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.date} • ${item.method} • ${item.sourceLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM ${item.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: onViewReceipt,
                child: const Text(
                  'View Receipt',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayPalCheckoutView extends StatefulWidget {
  const _PayPalCheckoutView({
    required this.approvalUrl,
    required this.returnUrl,
    required this.cancelUrl,
    required this.onApproved,
    required this.onCancelled,
  });

  final String approvalUrl;
  final String returnUrl;
  final String cancelUrl;
  final VoidCallback onApproved;
  final VoidCallback onCancelled;

  @override
  State<_PayPalCheckoutView> createState() => _PayPalCheckoutViewState();
}

class _PayPalCheckoutViewState extends State<_PayPalCheckoutView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                final url = request.url;
                if (url.startsWith(widget.returnUrl)) {
                  widget.onApproved();
                  return NavigationDecision.prevent;
                }
                if (url.startsWith(widget.cancelUrl)) {
                  widget.onCancelled();
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEF2FF))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onCancelled,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 6),
              const Text(
                'PayPal Checkout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: const [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    color: Color(0xFF2563EB),
                    backgroundColor: Color(0xFFDBEAFE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Verifying Payment',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We are securely connecting to the PayPal gateway. Please wait...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.booking,
    required this.onReceipt,
    required this.onContinue,
  });

  final BookingItem? booking;
  final VoidCallback onReceipt;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Success!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Payment has been confirmed',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 18),
            Text(
              'RM ${(booking?.amount ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Order Reference:',
                    value: booking?.id ?? '-',
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(
                    label: 'Gateway:',
                    value: 'PayPal SDK',
                    highlight: true,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Transaction Date:',
                    value: DateTime.now().toLocal().toString().split(' ').first,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReceipt,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    label: const Text(
                      'Receipt',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_right_alt_rounded),
                    label: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color:
                highlight ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            fontStyle: highlight ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  final String label;
  final String value;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
          Flexible(
            child: Container(
              padding:
                  isMono
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : EdgeInsets.zero,
              decoration:
                  isMono
                      ? BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      )
                      : null,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                  fontSize: isMono ? 11 : 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

