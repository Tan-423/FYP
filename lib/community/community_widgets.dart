part of 'community_screen.dart';

class _BlueIconButton extends StatelessWidget {
  const _BlueIconButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlue,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: kShadowBlue,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

Widget _imageFallbackPlaceholder() {
  return Container(
    height: 200,
    width: double.infinity,
    color: kSlate50,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined, color: kTextMuted),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.onLike,
    required this.onDelete,
    required this.onOpenComments,
  });

  final CommunityPost post;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: Text(
                    post.authorName.characters.first,
                    style: const TextStyle(color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: kText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        post.timestampLabel,
                        style: const TextStyle(color: kTextMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kTextMuted),
                  color: Colors.white,
                  onSelected: (value) async {
                    if (value != 'delete') return;
                    final shouldDelete =
                        await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Delete post?'),
                                content: const Text(
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                        ) ??
                        false;
                    if (shouldDelete) onDelete();
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 8),
                              Text('Delete Post'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(color: kText, fontSize: 14),
            ),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                    post.imageUrl!.startsWith('http')
                        ? Image.network(
                          post.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => _imageFallbackPlaceholder(),
                        )
                        : Image.file(
                          File(post.imageUrl!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => _imageFallbackPlaceholder(),
                        ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : kTextMuted,
                    size: 18,
                  ),
                  label: Text(
                    post.likesCount.toString(),
                    style: const TextStyle(color: kText),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onOpenComments,
                  icon: const Icon(Icons.comment, color: kTextMuted, size: 18),
                  label: Text(
                    post.commentsCount.toString(),
                    style: const TextStyle(color: kText),
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.place, size: 16, color: kTextMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          post.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.options,
    required this.selectedOptionId,
    required this.onVote,
  });

  final CommunityPoll poll;
  final List<PollOption> options;
  final String? selectedOptionId;
  final Future<void> Function(String optionId) onVote;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes;
    final showPercentages = selectedOptionId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: const TextStyle(
              color: kText,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (final option in options)
            _PollOptionTile(
              option: option,
              isSelected: selectedOptionId == option.id,
              totalVotes: totalVotes,
              showPercentage: showPercentages,
              onTap: () => onVote(option.id),
            ),
        ],
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.isSelected,
    required this.totalVotes,
    required this.showPercentage,
    required this.onTap,
  });

  final PollOption option;
  final bool isSelected;
  final int totalVotes;
  final bool showPercentage;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final currentVotes = option.votes;
    final percentage =
        totalVotes == 0 ? 0 : ((currentVotes / totalVotes) * 100).round();

    return GestureDetector(
      onTap: () async {
        await onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [kBlue.withOpacity(0.18), kBlue50]
                    : [Colors.white, kBlue50],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? kBlue : kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  color: isSelected ? kBlue : kText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (showPercentage)
              Text(
                '$percentage%',
                style: const TextStyle(color: kTextMuted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  bool get selected => isSelected;
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(color: Colors.white.withOpacity(0.92), child: child),
      ),
    );
  }
}
