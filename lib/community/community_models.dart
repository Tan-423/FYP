part of 'community_screen.dart';

String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

DateTime _dateFromField(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.imageUrl,
    required this.location,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final String? imageUrl;
  final String location;
  int likesCount;
  int commentsCount;
  final DateTime createdAt;

  String get timestampLabel => formatTimeAgo(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'imageUrl': imageUrl,
      'location': location,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': createdAt,
    };
  }

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CommunityPost(
      id: doc.id,
      authorId: (data['authorId'] ?? '') as String,
      authorName: (data['authorName'] ?? 'Anonymous') as String,
      content: (data['content'] ?? '') as String,
      imageUrl: data['imageUrl'] as String?,
      location: (data['location'] ?? '') as String,
      likesCount: (data['likesCount'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
      createdAt: _dateFromField(data['createdAt']),
    );
  }
}

class CommunityComment {
  CommunityComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  String get timestampLabel => formatTimeAgo(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt,
    };
  }

  factory CommunityComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CommunityComment(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      userName: (data['userName'] ?? 'Anonymous') as String,
      text: (data['text'] ?? '') as String,
      createdAt: _dateFromField(data['createdAt']),
    );
  }
}

enum GroupType { private, public }

class CommunityGroup {
  CommunityGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.code,
    required this.membersCount,
    required this.createdAt,
    required this.adminId,
  });

  final String id;
  final String name;
  final String description;
  final GroupType type;
  final String? code;
  int membersCount;
  final DateTime createdAt;
  final String adminId;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.name,
      'code': code,
      'membersCount': membersCount,
      'createdAt': createdAt,
      'adminId': adminId,
    };
  }

  factory CommunityGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeValue = (data['type'] ?? 'public') as String;
    return CommunityGroup(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      type: GroupType.values.firstWhere(
        (value) => value.name == typeValue,
        orElse: () => GroupType.public,
      ),
      code: data['code'] as String?,
      membersCount: (data['membersCount'] ?? 0) as int,
      createdAt: _dateFromField(data['createdAt']),
      adminId: (data['adminId'] ?? '') as String,
    );
  }
}

class CommunityPoll {
  CommunityPoll({
    required this.id,
    required this.question,
    required this.totalVotes,
    required this.createdAt,
    required this.creatorId,
  });

  final String id;
  final String question;
  int totalVotes;
  final DateTime createdAt;
  final String creatorId;

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'totalVotes': totalVotes,
      'createdAt': createdAt,
      'creatorId': creatorId,
    };
  }

  factory CommunityPoll.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CommunityPoll(
      id: doc.id,
      question: (data['question'] ?? '') as String,
      totalVotes: (data['totalVotes'] ?? 0) as int,
      createdAt: _dateFromField(data['createdAt']),
      creatorId: (data['creatorId'] ?? '') as String,
    );
  }
}

class PollOption {
  PollOption({required this.id, required this.label, required this.votes});

  final String id;
  final String label;
  int votes;

  Map<String, dynamic> toMap() {
    return {'label': label, 'votes': votes};
  }

  factory PollOption.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PollOption(
      id: doc.id,
      label: (data['label'] ?? '') as String,
      votes: (data['votes'] ?? 0) as int,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  String get timestampLabel => formatTimeAgo(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt,
    };
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      userName: (data['userName'] ?? 'Anonymous') as String,
      text: (data['text'] ?? '') as String,
      createdAt: _dateFromField(data['createdAt']),
    );
  }
}
