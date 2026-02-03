import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

part 'community_models.dart';
part 'community_firebase_service.dart';
part 'community_views.dart';
part 'community_widgets.dart';
part 'community_sheets.dart';

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
  final CommunityFirebaseService _service = CommunityFirebaseService();

  void _deletePost(String postId) {
    _service.deletePost(postId);
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
      builder:
          (context) => _NewPostSheet(
            onSubmit: (content, imagePath, location) async {
              try {
                await _service.createPost(
                  content: content,
                  imagePath: imagePath,
                  location: location,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceAll('Exception: ', ''),
                    ),
                  ),
                );
              }
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
      builder:
          (context) => _NewGroupSheet(
            onSubmit: (name, type, code) async {
              await _service.createGroup(name: name, type: type, code: code);
              if (!context.mounted) return;
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
      builder:
          (context) => _NewPollSheet(
            onSubmit: (question, options) async {
              await _service.createPoll(question: question, options: options);
              if (!context.mounted) return;
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
      builder: (context) => _CommentsSheet(postId: post.id, service: _service),
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
    final title =
        _activeTabIndex == 0
            ? 'Community'
            : _activeTabIndex == 1
            ? 'Groups'
            : 'Decisions';

    return Scaffold(
      backgroundColor: kSlate50,
      appBar:
          _selectedChat == null
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
        child:
            _selectedChat != null
                ? _ChatRoom(
                  group: _selectedChat!,
                  service: _service,
                  currentUserId: _service.currentUserId,
                  onBack: _leaveChat,
                )
                : IndexedStack(
                  index: _activeTabIndex,
                  children: [
                    StreamBuilder<List<CommunityPost>>(
                      stream: _service.streamPosts(),
                      builder: (context, snapshot) {
                        final posts = snapshot.data ?? [];
                        return _FeedTab(
                          posts: posts,
                          service: _service,
                          onNewPost: _openNewPostSheet,
                          onDelete: _deletePost,
                          onOpenComments: _openCommentsSheet,
                        );
                      },
                    ),
                    StreamBuilder<List<CommunityGroup>>(
                      stream: _service.streamGroups(),
                      builder: (context, snapshot) {
                        final groups = snapshot.data ?? [];
                        return _ChatsTab(
                          groups: groups,
                          service: _service,
                          onJoinChat: _openChat,
                          onNewGroup: _openNewGroupSheet,
                        );
                      },
                    ),
                    StreamBuilder<List<CommunityPoll>>(
                      stream: _service.streamPolls(),
                      builder: (context, snapshot) {
                        final polls = snapshot.data ?? [];
                        return _VoteTab(
                          polls: polls,
                          service: _service,
                          onNewPoll: _openNewPollSheet,
                        );
                      },
                    ),
                  ],
                ),
      ),
      bottomNavigationBar:
          _selectedChat == null
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
      floatingActionButton: null,
    );
  }
}
