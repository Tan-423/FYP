import 'dart:ui';

import 'package:flutter/material.dart';

const Color kBlue = Color(0xFF2563EB);
const Color kBlue50 = Color(0xFFEFF6FF);
const Color kSlate50 = Color(0xFFF8FAFC);
const Color kBorder = Color(0xFFE2E8F0);
const Color kText = Color(0xFF0F172A);
const Color kTextMuted = Color(0xFF475569);
const Color kShadowBlue = Color(0xFFBFDBFE);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _activeTabIndex = 0;
  CommunityGroup? _selectedChat;

  final List<CommunityPost> _posts = [
    CommunityPost(
      id: 1,
      author: 'Lai Heng',
      content:
          'Just reached Langkawi! The SkyBridge view is absolutely stunning today.',
      imageUrl:
          'https://images.unsplash.com/photo-1544918877-460635b6d13e?w=800&auto=format&fit=crop',
      location: 'Langkawi, Kedah',
      likes: 12,
      isLiked: false,
      timestamp: '2h ago',
      comments: [
        CommunityComment(
          id: 101,
          user: 'John Doe',
          text: "Wow! I'm going there next week!",
          timestamp: '1h ago',
        ),
        CommunityComment(
          id: 102,
          user: 'Sarah W.',
          text: "Don't forget to try the local laksa!",
          timestamp: '30m ago',
        ),
      ],
    ),
  ];

  final List<CommunityGroup> _groups = [
    CommunityGroup(
      id: 1,
      name: 'Penang Foodie Trip',
      description: "Exploring George Town's best street food.",
      type: GroupType.private,
      code: 'PF123',
      members: 4,
    ),
    CommunityGroup(
      id: 2,
      name: 'Solo Backpackers MY',
      description: 'Sharing tips for budget travel across Malaysia.',
      type: GroupType.public,
      members: 156,
    ),
  ];

  final List<CommunityPoll> _polls = [
    CommunityPoll(
      id: 1,
      question: 'Where should we stay in Penang?',
      options: [
        PollOption(id: 'a', label: 'Batu Ferringhi Resort', votes: 3),
        PollOption(id: 'b', label: 'George Town Boutique Hotel', votes: 5),
        PollOption(id: 'c', label: 'AirBnB near Gurney Drive', votes: 2),
      ],
      totalVotes: 10,
    ),
  ];

  final Map<int, String> _votedOptions = {};

  void _toggleLike(int postId) {
    setState(() {
      for (final post in _posts) {
        if (post.id == postId) {
          post.isLiked = !post.isLiked;
          post.likes += post.isLiked ? 1 : -1;
        }
      }
    });
  }

  void _deletePost(int postId) {
    setState(() {
      _posts.removeWhere((post) => post.id == postId);
    });
  }

  void _addComment(int postId, String text) {
    setState(() {
      for (final post in _posts) {
        if (post.id == postId) {
          post.comments.add(
            CommunityComment(
              id: DateTime.now().millisecondsSinceEpoch,
              user: 'Me',
              text: text,
              timestamp: 'Just now',
            ),
          );
        }
      }
    });
  }

  void _openNewPostSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _NewPostSheet(
        onSubmit: (post) {
          setState(() {
            _posts.insert(0, post);
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openNewGroupSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _NewGroupSheet(
        onSubmit: (group) {
          setState(() {
            _groups.insert(0, group);
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openNewPollSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _NewPollSheet(
        onSubmit: (poll) {
          setState(() {
            _polls.insert(0, poll);
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openCommentsSheet(CommunityPost post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CommentsSheet(
        post: post,
        onAddComment: (text) {
          if (text.trim().isEmpty) return;
          _addComment(post.id, text.trim());
        },
      ),
    );
  }

  void _openChat(CommunityGroup group) {
    setState(() => _selectedChat = group);
  }

  void _leaveChat() {
    setState(() => _selectedChat = null);
  }

  @override
  Widget build(BuildContext context) {
    final title = _activeTabIndex == 0
        ? 'Community'
        : _activeTabIndex == 1
            ? 'Groups'
            : 'Decisions';

    return Scaffold(
      backgroundColor: kSlate50,
      appBar: _selectedChat == null
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: kText,
              elevation: 0,
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kBlue,
                ),
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Text(
                      'TH',
                      style: TextStyle(fontSize: 11, color: kText),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: _selectedChat != null
            ? _ChatRoom(
                group: _selectedChat!,
                onBack: _leaveChat,
              )
            : IndexedStack(
                index: _activeTabIndex,
                children: [
                  _FeedTab(
                    posts: _posts,
                    onNewPost: _openNewPostSheet,
                    onLike: _toggleLike,
                    onDelete: _deletePost,
                    onOpenComments: _openCommentsSheet,
                  ),
                  _ChatsTab(
                    groups: _groups,
                    onJoinChat: _openChat,
                    onNewGroup: _openNewGroupSheet,
                  ),
                  _VoteTab(
                    polls: _polls,
                    votedOptions: _votedOptions,
                    onVote: (pollId, optionId) {
                      setState(() => _votedOptions[pollId] = optionId);
                    },
                    onNewPoll: _openNewPollSheet,
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _selectedChat == null
          ? NavigationBar(
              backgroundColor: Colors.white,
              selectedIndex: _activeTabIndex,
              indicatorColor: kBlue.withOpacity(0.15),
              onDestinationSelected: (index) {
                setState(() => _activeTabIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.public),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.how_to_vote_rounded),
                  label: 'Vote',
                ),
              ],
            )
          : null,
      floatingActionButton: _selectedChat == null && _activeTabIndex == 0
          ? FloatingActionButton(
              onPressed: _openNewPostSheet,
              backgroundColor: kBlue,
              elevation: 3,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrl,
    required this.location,
    required this.likes,
    required this.isLiked,
    required this.timestamp,
    List<CommunityComment>? comments,
  }) : comments = comments ?? [];

  final int id;
  final String author;
  final String content;
  final String? imageUrl;
  final String location;
  int likes;
  bool isLiked;
  final String timestamp;
  final List<CommunityComment> comments;
}

class CommunityComment {
  CommunityComment({
    required this.id,
    required this.user,
    required this.text,
    required this.timestamp,
  });

  final int id;
  final String user;
  final String text;
  final String timestamp;
}

enum GroupType { private, public }

class CommunityGroup {
  CommunityGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.code,
    required this.members,
  });

  final int id;
  final String name;
  final String description;
  final GroupType type;
  final String? code;
  final int members;
}

class CommunityPoll {
  CommunityPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.totalVotes,
  });

  final int id;
  final String question;
  final List<PollOption> options;
  final int totalVotes;
}

class PollOption {
  PollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  final String id;
  final String label;
  final int votes;
}

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

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.posts,
    required this.onNewPost,
    required this.onLike,
    required this.onDelete,
    required this.onOpenComments,
  });

  final List<CommunityPost> posts;
  final VoidCallback onNewPost;
  final ValueChanged<int> onLike;
  final ValueChanged<int> onDelete;
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
        for (final post in posts)
          _PostCard(
            post: post,
            onLike: () => onLike(post.id),
            onDelete: () => onDelete(post.id),
            onOpenComments: () => onOpenComments(post),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onDelete,
    required this.onOpenComments,
  });

  final CommunityPost post;
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
                    post.author.characters.first,
                    style: const TextStyle(color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(
                          color: kText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        post.timestamp,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kTextMuted),
                  color: Colors.white,
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent),
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
                child: Image.network(
                  post.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked
                        ? Colors.redAccent
                        : kTextMuted,
                    size: 18,
                  ),
                  label: Text(
                    post.likes.toString(),
                    style: const TextStyle(color: kText),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onOpenComments,
                  icon: const Icon(Icons.comment, color: kTextMuted, size: 18),
                  label: Text(
                    post.comments.length.toString(),
                    style: const TextStyle(color: kText),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: kTextMuted),
                    const SizedBox(width: 4),
                    Text(
                      post.location,
                      style: const TextStyle(color: kTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.groups,
    required this.onJoinChat,
    required this.onNewGroup,
  });

  final List<CommunityGroup> groups;
  final ValueChanged<CommunityGroup> onJoinChat;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
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
            _BlueIconButton(onPressed: onNewGroup, icon: Icons.add),
          ],
        ),
        const SizedBox(height: 12),
        for (final group in groups)
          GestureDetector(
            onTap: () => onJoinChat(group),
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
                      color: group.type == GroupType.private
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : kBlue50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.people,
                      color: group.type == GroupType.private
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        group.type == GroupType.private
                            ? Icons.lock
                            : Icons.public,
                        size: 14,
                        color: group.type == GroupType.private
                            ? const Color(0xFFF59E0B)
                            : kBlue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.members} members',
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
  const _ChatRoom({required this.group, required this.onBack});

  final CommunityGroup group;
  final VoidCallback onBack;

  @override
  State<_ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<_ChatRoom> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 1,
      user: 'Lee',
      text: 'Has everyone voted for the hotel yet?',
      time: '10:15 AM',
      isMe: false,
    ),
    ChatMessage(
      id: 2,
      user: 'Me',
      text: "Not yet, I'm checking the locations on the map.",
      time: '10:16 AM',
      isMe: true,
    ),
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch,
          user: 'Me',
          text: _controller.text.trim(),
          time: 'Just now',
          isMe: true,
        ),
      );
      _controller.clear();
    });
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
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: kBlue50,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: message.isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!message.isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.user,
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
                            colors: message.isMe
                                ? [const Color(0xFF3B82F6), kBlue]
                                : [Colors.white, kBlue50],
                          ),
                          borderRadius: BorderRadius.circular(18).copyWith(
                            topRight:
                                message.isMe ? const Radius.circular(4) : null,
                            topLeft:
                                message.isMe ? null : const Radius.circular(4),
                          ),
                          border: message.isMe
                              ? null
                              : Border.all(color: kBorder),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.isMe ? Colors.white : kText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.time,
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

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.user,
    required this.text,
    required this.time,
    required this.isMe,
  });

  final int id;
  final String user;
  final String text;
  final String time;
  final bool isMe;
}

class _VoteTab extends StatelessWidget {
  const _VoteTab({
    required this.polls,
    required this.votedOptions,
    required this.onVote,
    required this.onNewPoll,
  });

  final List<CommunityPoll> polls;
  final Map<int, String> votedOptions;
  final void Function(int pollId, String optionId) onVote;
  final VoidCallback onNewPoll;

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
        for (final poll in polls)
          _PollCard(
            poll: poll,
            selectedOptionId: votedOptions[poll.id],
            onVote: (optionId) => onVote(poll.id, optionId),
          ),
      ],
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.selectedOptionId,
    required this.onVote,
  });

  final CommunityPoll poll;
  final String? selectedOptionId;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes + (selectedOptionId != null ? 1 : 0);

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
          for (final option in poll.options)
            _PollOptionTile(
              option: option,
              isSelected: selectedOptionId == option.id,
              totalVotes: totalVotes,
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
    required this.onTap,
  });

  final PollOption option;
  final bool isSelected;
  final int totalVotes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentVotes = option.votes + (isSelected ? 1 : 0);
    final percentage = totalVotes == 0
        ? 0
        : ((currentVotes / totalVotes) * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [kBlue.withOpacity(0.18), kBlue50]
                : [Colors.white, kBlue50],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kBlue : kBorder,
          ),
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
            if (selected)
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
        child: Container(
          color: Colors.white.withOpacity(0.92),
          child: child,
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.onAddComment});

  final CommunityPost post;
  final ValueChanged<String> onAddComment;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: kTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.post.comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: kTextMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.post.comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final comment = widget.post.comments[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(
                                  comment.user.characters.first,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: kText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kBorder),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            comment.user,
                                            style: const TextStyle(
                                              color: kText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            comment.timestamp,
                                            style: const TextStyle(
                                              color: kTextMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.text,
                                        style: const TextStyle(
                                          color: kText,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: kTextMuted),
                        filled: true,
                        fillColor: kSlate50,
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
                      onPressed: () {
                        widget.onAddComment(_controller.text);
                        _controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet({required this.onSubmit});

  final ValueChanged<CommunityPost> onSubmit;

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Post',
                  style: TextStyle(
                    color: kBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: kTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: const TextStyle(color: kText),
              decoration: InputDecoration(
                hintText: 'Share your travel experience...',
                hintStyle: const TextStyle(color: kTextMuted),
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageController,
              style: const TextStyle(color: kText),
              decoration: InputDecoration(
                hintText: 'Image URL (optional)',
                hintStyle: const TextStyle(color: kTextMuted),
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: kShadowBlue,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (_contentController.text.trim().isEmpty) return;
                    widget.onSubmit(
                      CommunityPost(
                        id: DateTime.now().millisecondsSinceEpoch,
                        author: 'Me',
                        content: _contentController.text.trim(),
                        imageUrl: _imageController.text.trim().isEmpty
                            ? null
                            : _imageController.text.trim(),
                        location: 'Kuala Lumpur, MY',
                        likes: 0,
                        isLiked: false,
                        timestamp: 'Just now',
                        comments: [],
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Post to Community'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewGroupSheet extends StatefulWidget {
  const _NewGroupSheet({required this.onSubmit});

  final ValueChanged<CommunityGroup> onSubmit;

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Travel Group',
                  style: TextStyle(
                    color: kBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: kTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: kText),
              decoration: InputDecoration(
                hintText: 'Group Name',
                hintStyle: const TextStyle(color: kTextMuted),
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: kShadowBlue,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (_nameController.text.trim().isEmpty) return;
                    final code = 'LK${100 + (DateTime.now().second % 900)}';
                    widget.onSubmit(
                      CommunityGroup(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: _nameController.text.trim(),
                        description: 'Travel group',
                        type: GroupType.private,
                        code: code,
                        members: 1,
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Create Group'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewPollSheet extends StatefulWidget {
  const _NewPollSheet({required this.onSubmit});

  final ValueChanged<CommunityPoll> onSubmit;

  @override
  State<_NewPollSheet> createState() => _NewPollSheetState();
}

class _NewPollSheetState extends State<_NewPollSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _submitPoll() {
    final question = _questionController.text.trim();
    final options =
        _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty);
    if (question.isEmpty || options.length < 2) return;

    widget.onSubmit(
      CommunityPoll(
        id: DateTime.now().millisecondsSinceEpoch,
        question: question,
        options: [
          for (final entry in options.toList().asMap().entries)
            PollOption(
              id: entry.key.toString(),
              label: entry.value,
              votes: 0,
            ),
        ],
        totalVotes: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Poll',
                  style: TextStyle(
                    color: kBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: kTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              style: const TextStyle(color: kText),
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle: const TextStyle(color: kTextMuted),
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final controller in _optionControllers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: kText),
                  decoration: InputDecoration(
                    hintText:
                        'Option ${_optionControllers.indexOf(controller) + 1}',
                    hintStyle: const TextStyle(color: kTextMuted),
                    filled: true,
                    fillColor: kSlate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _addOption,
                child: const Text(
                  '+ Add Option',
                  style: TextStyle(color: kBlue),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: kShadowBlue,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submitPoll,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Start Vote'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
