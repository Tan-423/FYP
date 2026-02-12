part of 'community_screen.dart';

class CommunityFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUserId => _auth.currentUser?.uid ?? 'guest';

  String get _currentUserName {
    final user = _auth.currentUser;
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Traveler';
  }

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _db.collection('community_posts');
  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _db.collection('community_groups');
  CollectionReference<Map<String, dynamic>> get _pollsRef =>
      _db.collection('community_polls');

  Stream<List<CommunityPost>> streamPosts() {
    return _postsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityPost.fromDoc).toList());
  }

  Stream<List<CommunityGroup>> streamGroups() {
    final publicStream = _groupsRef
        .where('type', isEqualTo: GroupType.public.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityGroup.fromDoc).toList());
    final userId = currentUserId;
    if (userId == 'guest') {
      return publicStream;
    }

    final memberStream = _groupsRef
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityGroup.fromDoc).toList());

    return _mergeGroupStreams(publicStream, memberStream);
  }

  Stream<List<CommunityPoll>> streamPolls() {
    return _pollsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityPoll.fromDoc).toList());
  }

  Stream<List<CommunityComment>> streamComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CommunityComment.fromDoc).toList(),
        );
  }

  Stream<bool> streamLikeStatus(String postId) {
    final userId = currentUserId;
    if (userId == 'guest') {
      return Stream.value(false);
    }
    return _postsRef
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<PollOption>> streamPollOptions(String pollId) {
    return _pollsRef
        .doc(pollId)
        .collection('options')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PollOption.fromDoc).toList());
  }

  Stream<String?> streamUserVote(String pollId) {
    final userId = currentUserId;
    if (userId == 'guest') {
      return Stream.value(null);
    }
    return _pollsRef
        .doc(pollId)
        .collection('votes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['optionId'] as String?);
  }

  Stream<List<ChatMessage>> streamMessages(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> createPost({
    required String content,
    String? imagePath,
    required String location,
  }) async {
    final postRef = _postsRef.doc();
    String? imageUrl;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final storedImage = await _persistPostImage(imagePath, postRef.id);
        final storageRef = _storage
            .ref()
            .child('community_posts')
            .child('${postRef.id}.jpg');
        await storageRef.putFile(storedImage);
        imageUrl = await storageRef.getDownloadURL();
      } catch (error) {
        throw Exception('Failed to upload image.');
      }
    }

    final post = CommunityPost(
      id: postRef.id,
      authorId: currentUserId,
      authorName: _currentUserName,
      content: content,
      imageUrl: imageUrl,
      location: location,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );
    await postRef.set(post.toMap());
  }

  Future<File> _persistPostImage(String sourcePath, String postId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/community_image');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final fileName = '${postId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = '${imagesDir.path}/$fileName';
    return File(sourcePath).copy(targetPath);
  }

  Future<void> deletePost(String postId) async {
    await _postsRef.doc(postId).delete();
  }

  Future<void> addComment(String postId, String text) async {
    final commentRef = _postsRef.doc(postId).collection('comments').doc();
    final comment = CommunityComment(
      id: commentRef.id,
      userId: currentUserId,
      userName: _currentUserName,
      text: text,
      createdAt: DateTime.now(),
    );
    await _db.runTransaction((transaction) async {
      transaction.set(commentRef, comment.toMap());
      transaction.update(_postsRef.doc(postId), {
        'commentsCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> toggleLike(String postId) async {
    final userId = currentUserId;
    if (userId == 'guest') return;
    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    await _db.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likesCount': FieldValue.increment(-1)});
      } else {
        transaction.set(likeRef, {'createdAt': DateTime.now()});
        transaction.update(postRef, {'likesCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> createGroup({
    required String name,
    required GroupType type,
    String? code,
  }) async {
    final groupRef = _groupsRef.doc();
    final group = CommunityGroup(
      id: groupRef.id,
      name: name,
      description: 'Travel group',
      type: type,
      code: code,
      membersCount: 1,
      createdAt: DateTime.now(),
      adminId: currentUserId,
    );
    await groupRef.set({
      ...group.toMap(),
      'memberIds': [currentUserId],
    });
    await groupRef.collection('members').doc(currentUserId).set({
      'joinedAt': DateTime.now(),
      'userName': _currentUserName,
    });
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
  }) async {
    await _groupsRef.doc(groupId).update({
      'name': name,
      'description': description,
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await _groupsRef.doc(groupId).delete();
  }

  Future<CommunityGroup?> findGroupByCode(String code) async {
    final snapshot =
        await _groupsRef.where('code', isEqualTo: code).limit(1).get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return CommunityGroup.fromDoc(snapshot.docs.first);
  }

  Future<void> joinGroup(String groupId) async {
    final groupRef = _groupsRef.doc(groupId);
    final memberRef = groupRef.collection('members').doc(currentUserId);
    await _db.runTransaction((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);
      if (memberSnapshot.exists) {
        transaction.update(groupRef, {
          'memberIds': FieldValue.arrayUnion([currentUserId]),
        });
        return;
      }
      transaction.set(memberRef, {
        'joinedAt': DateTime.now(),
        'userName': _currentUserName,
      });
      transaction.update(groupRef, {
        'membersCount': FieldValue.increment(1),
        'memberIds': FieldValue.arrayUnion([currentUserId]),
      });
    });
  }

  Stream<List<CommunityGroup>> _mergeGroupStreams(
    Stream<List<CommunityGroup>> publicStream,
    Stream<List<CommunityGroup>> memberStream,
  ) {
    late StreamController<List<CommunityGroup>> controller;
    StreamSubscription<List<CommunityGroup>>? publicSub;
    StreamSubscription<List<CommunityGroup>>? memberSub;
    var publicGroups = <CommunityGroup>[];
    var memberGroups = <CommunityGroup>[];

    void emit() {
      final merged = <String, CommunityGroup>{};
      for (final group in publicGroups) {
        merged[group.id] = group;
      }
      for (final group in memberGroups) {
        merged[group.id] = group;
      }
      final mergedList =
          merged.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(mergedList);
    }

    controller = StreamController<List<CommunityGroup>>(
      onListen: () {
        publicSub = publicStream.listen((groups) {
          publicGroups = groups;
          emit();
        }, onError: controller.addError);
        memberSub = memberStream.listen((groups) {
          memberGroups = groups;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await publicSub?.cancel();
        await memberSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> sendMessage(String groupId, String text) async {
    final messageRef = _groupsRef.doc(groupId).collection('messages').doc();
    final message = ChatMessage(
      id: messageRef.id,
      userId: currentUserId,
      userName: _currentUserName,
      text: text,
      createdAt: DateTime.now(),
    );
    await messageRef.set(message.toMap());
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
  }) async {
    final pollRef = _pollsRef.doc();
    final poll = CommunityPoll(
      id: pollRef.id,
      question: question,
      totalVotes: 0,
      createdAt: DateTime.now(),
      creatorId: currentUserId,
    );
    await pollRef.set(poll.toMap());
    for (final option in options) {
      await pollRef.collection('options').add({'label': option, 'votes': 0});
    }
  }

  Future<void> deletePoll(String pollId) async {
    await _pollsRef.doc(pollId).delete();
  }

  Future<void> vote(String pollId, String optionId) async {
    final userId = currentUserId;
    if (userId == 'guest') {
      throw Exception('Login required.');
    }
    final pollRef = _pollsRef.doc(pollId);
    final voteRef = pollRef.collection('votes').doc(userId);
    final optionRef = pollRef.collection('options').doc(optionId);
    await _db.runTransaction((transaction) async {
      final voteSnap = await transaction.get(voteRef);
      if (voteSnap.exists) {
        final previousOptionId = voteSnap.data()?['optionId'] as String?;
        if (previousOptionId == optionId) {
          return;
        }
        if (previousOptionId != null) {
          final previousOptionRef = pollRef
              .collection('options')
              .doc(previousOptionId);
          transaction.update(previousOptionRef, {
            'votes': FieldValue.increment(-1),
          });
        }
        transaction.update(optionRef, {'votes': FieldValue.increment(1)});
        transaction.update(voteRef, {'optionId': optionId});
      } else {
        transaction.set(voteRef, {'optionId': optionId});
        transaction.update(optionRef, {'votes': FieldValue.increment(1)});
        transaction.update(pollRef, {'totalVotes': FieldValue.increment(1)});
      }
    });
  }
}
