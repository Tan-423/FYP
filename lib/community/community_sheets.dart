part of 'community_screen.dart';

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId, required this.service});

  final String postId;
  final CommunityFirebaseService service;

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
                child: StreamBuilder<List<CommunityComment>>(
                  stream: widget.service.streamComments(widget.postId),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: kTextMuted),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: Text(
                                comment.userName.characters.first,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          comment.userName,
                                          style: const TextStyle(
                                            color: kText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          comment.timestampLabel,
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
                      onPressed: () async {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        await widget.service.addComment(widget.postId, text);
                        if (!mounted) return;
                        _controller.clear();
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

  final void Function(String content, String? imagePath, String location)
  onSubmit;

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  bool _isLocating = false;

  Future<void> _pickImageFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted) return;
    setState(() => _pickedImage = image);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are off. Please enable them.'),
          ),
        );
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final rawParts =
          [
            place?.locality,
            place?.administrativeArea,
            place?.country,
          ].where((part) => part?.isNotEmpty ?? false).cast<String>().toList();
      final seen = <String>{};
      final parts = <String>[];
      for (final part in rawParts) {
        final key = part.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        parts.add(part);
      }
      final location = parts.isNotEmpty ? parts.join(', ') : 'Current location';

      if (!mounted) return;
      if (place?.country == 'United States') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location looks inaccurate. Enable GPS and Precise location.',
            ),
          ),
        );
      }
      setState(() => _locationController.text = location);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch location.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(
                      _pickedImage == null ? 'Add Photo' : 'Change Photo',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_pickedImage != null)
                  IconButton(
                    onPressed: () => setState(() => _pickedImage = null),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove photo',
                  ),
              ],
            ),
            if (_pickedImage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_pickedImage!.path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              style: const TextStyle(color: kText),
              decoration: InputDecoration(
                hintText: 'Tag location (e.g., George Town, Penang)',
                hintStyle: const TextStyle(color: kTextMuted),
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  onPressed: _isLocating ? null : _useCurrentLocation,
                  icon:
                      _isLocating
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.my_location),
                  tooltip: 'Use current location',
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
                    final location =
                        _locationController.text.trim().isEmpty
                            ? 'Location not set'
                            : _locationController.text.trim();
                    widget.onSubmit(
                      _contentController.text.trim(),
                      _pickedImage?.path,
                      location,
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

  final void Function(String name, GroupType type, String? code) onSubmit;

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final TextEditingController _nameController = TextEditingController();
  GroupType _selectedType = GroupType.private;

  String _generateInviteCode() {
    final number = 100000 + Random().nextInt(900000);
    return 'LK$number';
  }

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
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Private'),
                  selected: _selectedType == GroupType.private,
                  onSelected: (_) {
                    setState(() => _selectedType = GroupType.private);
                  },
                  selectedColor: kBlue.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color:
                        _selectedType == GroupType.private ? kBlue : kTextMuted,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Public'),
                  selected: _selectedType == GroupType.public,
                  onSelected: (_) {
                    setState(() => _selectedType = GroupType.public);
                  },
                  selectedColor: kBlue.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color:
                        _selectedType == GroupType.public ? kBlue : kTextMuted,
                  ),
                ),
              ],
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
                    final code =
                        _selectedType == GroupType.private
                            ? _generateInviteCode()
                            : null;
                    widget.onSubmit(
                      _nameController.text.trim(),
                      _selectedType,
                      code,
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

  final void Function(String question, List<String> options) onSubmit;

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
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty);
    if (question.isEmpty || options.length < 2) return;

    widget.onSubmit(question, options.toList());
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
