part of 'community_screen.dart';

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.posts,
    required this.service,
    required this.onNewPost,
    required this.onDelete,
    required this.onOpenComments,
  });

  final List<CommunityPost> posts;
  final CommunityFirebaseService service;
  final VoidCallback onNewPost;
  final ValueChanged<String> onDelete;
  final ValueChanged<CommunityPost> onOpenComments;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kBlue,
                letterSpacing: 1.2,
              ),
            ),
            _BlueIconButton(onPressed: onNewPost, icon: Icons.add),
          ],
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No posts yet. Start the conversation!',
                style: const TextStyle(color: kTextMuted),
              ),
            ),
          )
        else
          for (final post in posts)
            StreamBuilder<bool>(
              stream: service.streamLikeStatus(post.id),
              builder: (context, snapshot) {
                final isLiked = snapshot.data ?? false;
                return _PostCard(
                  post: post,
                  isLiked: isLiked,
                  onLike: () => service.toggleLike(post.id),
                  onDelete: () => onDelete(post.id),
                  onOpenComments: () => onOpenComments(post),
                  currentUserId: service.currentUserId,
                );
              },
            ),
      ],
    );
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab({
    required this.groups,
    required this.service,
    required this.onJoinChat,
    required this.onNewGroup,
    required this.onEditGroup,
    required this.onDeleteGroup,
  });

  final List<CommunityGroup> groups;
  final CommunityFirebaseService service;
  final ValueChanged<CommunityGroup> onJoinChat;
  final VoidCallback onNewGroup;
  final ValueChanged<CommunityGroup> onEditGroup;
  final ValueChanged<String> onDeleteGroup;

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinWithCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final match = await widget.service.findGroupByCode(code);
    if (match == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite code not found.')));
      return;
    }
    await widget.service.joinGroup(match.id);
    if (!mounted) return;
    widget.onJoinChat(match);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Join Private Group',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: kBlue, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: kText),
                decoration: InputDecoration(
                  hintText: 'Invite code',
                  hintStyle: const TextStyle(color: kTextMuted),
                  filled: true,
                  fillColor: kSlate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _joinWithCode,
              style: FilledButton.styleFrom(backgroundColor: kBlue),
              child: const Text('Join'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Travel Groups',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kBlue,
                letterSpacing: 1.1,
              ),
            ),
            _BlueIconButton(onPressed: widget.onNewGroup, icon: Icons.add),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'No groups yet. Create one to get started.',
                style: const TextStyle(color: kTextMuted),
              ),
            ),
          )
        else
          for (final group in widget.groups)
            GestureDetector(
              onTap: () => widget.onJoinChat(group),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color:
                            group.type == GroupType.private
                                ? const Color(0xFFF59E0B).withOpacity(0.15)
                                : kBlue50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.people,
                        color:
                            group.type == GroupType.private
                                ? const Color(0xFFF59E0B)
                                : kBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            group.description,
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (group.adminId == widget.service.currentUserId)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: kTextMuted),
                        color: Colors.white,
                        onSelected: (value) async {
                          if (value == 'edit') {
                            widget.onEditGroup(group);
                          } else if (value == 'delete') {
                            final shouldDelete =
                                await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Delete group?'),
                                        content: const Text(
                                          'This will delete all messages and remove all members.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                ) ??
                                false;
                            if (shouldDelete) widget.onDeleteGroup(group.id);
                          }
                        },
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: kBlue),
                                    SizedBox(width: 8),
                                    Text('Edit Group'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Delete Group'),
                                  ],
                                ),
                              ),
                            ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(
                            group.type == GroupType.private
                                ? Icons.lock
                                : Icons.public,
                            size: 14,
                            color:
                                group.type == GroupType.private
                                    ? const Color(0xFFF59E0B)
                                    : kBlue,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.membersCount} members',
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ChatRoom extends StatefulWidget {
  const _ChatRoom({
    required this.group,
    required this.service,
    required this.currentUserId,
    required this.onBack,
  });

  final CommunityGroup group;
  final CommunityFirebaseService service;
  final String currentUserId;
  final VoidCallback onBack;

  @override
  State<_ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<_ChatRoom> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    widget.service.sendMessage(widget.group.id, _controller.text.trim());
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.chevron_left, color: kText),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.name,
                      style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.group.type == GroupType.private
                          ? 'Invite Code: ${widget.group.code}'
                          : 'Public Group',
                      style: const TextStyle(color: kTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: widget.service.streamMessages(widget.group.id),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              return Container(
                color: kBlue50,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.userId == widget.currentUserId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment:
                            isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                message.userName,
                                style: const TextStyle(
                                  color: kTextMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    isMe
                                        ? [const Color(0xFF3B82F6), kBlue]
                                        : [Colors.white, kBlue50],
                              ),
                              borderRadius: BorderRadius.circular(18).copyWith(
                                topRight:
                                    isMe ? const Radius.circular(4) : null,
                                topLeft: isMe ? null : const Radius.circular(4),
                              ),
                              border: isMe ? null : Border.all(color: kBorder),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : kText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.timestampLabel,
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: kText),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(color: kTextMuted),
                    filled: true,
                    fillColor: kSlate50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: kBlue,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: kShadowBlue,
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoteTab extends StatelessWidget {
  const _VoteTab({
    required this.polls,
    required this.service,
    required this.onNewPoll,
    required this.onDeletePoll,
  });

  final List<CommunityPoll> polls;
  final CommunityFirebaseService service;
  final VoidCallback onNewPoll;
  final ValueChanged<String> onDeletePoll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Group Decisions',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kBlue,
                letterSpacing: 1.1,
              ),
            ),
            _BlueIconButton(onPressed: onNewPoll, icon: Icons.add),
          ],
        ),
        const SizedBox(height: 12),
        if (polls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No polls yet. Start a vote!',
                style: const TextStyle(color: kTextMuted),
              ),
            ),
          )
        else
          for (final poll in polls)
            StreamBuilder<List<PollOption>>(
              stream: service.streamPollOptions(poll.id),
              builder: (context, optionsSnapshot) {
                final options = optionsSnapshot.data ?? [];
                return StreamBuilder<String?>(
                  stream: service.streamUserVote(poll.id),
                  builder: (context, voteSnapshot) {
                    return _PollCard(
                      poll: poll,
                      options: options,
                      selectedOptionId: voteSnapshot.data,
                      currentUserId: service.currentUserId,
                      onVote: (optionId) async {
                        try {
                          await service.vote(poll.id, optionId);
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to submit vote.'),
                            ),
                          );
                        }
                      },
                      onDelete: () => onDeletePoll(poll.id),
                    );
                  },
                );
              },
            ),
      ],
    );
  }
}
