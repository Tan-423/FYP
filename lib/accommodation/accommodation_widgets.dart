import 'package:flutter/material.dart';

import 'accommodation_models.dart';

const String fallbackAccommodationImageUrl =
    'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=800&q=80';

class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({
    required this.notifications,
    required this.onDismiss,
    super.key,
  });

  final List<NotificationItem> notifications;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children:
            notifications
                .map(
                  (note) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xF21F2937),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.message,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onDismiss(note.id),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class CardContainer extends StatelessWidget {
  const CardContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AccommodationImage extends StatelessWidget {
  const AccommodationImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl.trim().isEmpty ? fallbackAccommodationImageUrl : imageUrl.trim();
    return Image.network(
      resolved,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.network(
        fallbackAccommodationImageUrl,
        fit: fit,
      ),
    );
  }
}

class InputField extends StatelessWidget {
  const InputField({
    required this.icon,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.controller,
    super.key,
  });

  final IconData icon;
  final String hint;
  final String value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              enabled: onChanged != null || controller != null,
              controller: controller,
              initialValue: controller == null ? value : null,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentTile extends StatelessWidget {
  const PaymentTile({
    required this.icon,
    required this.title,
    required this.active,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? const Color(0xFF2563EB) : Colors.black38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF1E3A8A) : Colors.black54,
              ),
            ),
          ),
          if (active) const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }
}

class RuleItem extends StatelessWidget {
  const RuleItem(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 6, color: Colors.black38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }
}

class FormFieldContainer extends StatelessWidget {
  const FormFieldContainer({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black45,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.onClear, super.key});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.black26),
            const SizedBox(height: 8),
            const Text('No accommodations found matching filters.'),
            TextButton(onPressed: onClear, child: const Text('Clear Filters')),
          ],
        ),
      ),
    );
  }
}

class InfoEmptyState extends StatelessWidget {
  const InfoEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black12),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyTrips extends StatelessWidget {
  const EmptyTrips({required this.onExplore, super.key});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.explore, size: 50, color: Colors.black26),
        const SizedBox(height: 12),
        const Text('No active bookings found.'),
        TextButton(onPressed: onExplore, child: const Text('Start exploring')),
      ],
    );
  }
}

class NavButton extends StatelessWidget {
  const NavButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF2563EB) : Colors.black38,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF2563EB) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
