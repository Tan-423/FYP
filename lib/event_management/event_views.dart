part of 'event_management.dart';

mixin EventManagementViews on State<EventManagementScreen>, EventManagementActions {
  Widget _buildEventImage(String imageRef, {BoxFit fit = BoxFit.cover}) {
    final resolved = imageRef.trim().isEmpty ? _fallbackImageUrl : imageRef.trim();
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(_fallbackImageUrl, fit: fit),
      );
    }
    return Image.asset(resolved, fit: fit);
  }
  Widget _buildNotificationBar() {
    if (_notificationMessage.isEmpty) {
      return const SizedBox(height: 0);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _notificationIsError ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _notificationIsError ? Icons.error_outline : Icons.check_circle,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _notificationMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _notificationMessage = ''),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Event Management Gateway',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loginAsTraveler,
                icon: const Icon(Icons.person),
                label: const Text('Login as Traveler'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openOrganizerLogin,
                icon: const Icon(Icons.apartment),
                label: const Text('Login as Organizer'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerLoginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => _selectView(EventView.auth),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Organizer Portal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _organizerEmailController,
              label: 'Work Email',
              hint: 'Enter work email',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _organizerPasswordController,
                  obscureText: !_showOrganizerPassword,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showOrganizerPassword = !_showOrganizerPassword),
                      icon: Icon(
                        _showOrganizerPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAuthenticating ? null : _handleOrganizerLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isAuthenticating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Authorize Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_view) {
      case EventView.auth:
        return _buildAuthView();
      case EventView.organizerLogin:
        return _buildOrganizerLoginView();
      case EventView.explore:
        return _buildExploreView();
      case EventView.detail:
        return _buildDetailView();
      case EventView.tickets:
        return _buildTicketsView();
      case EventView.manage:
        return _buildManageView();
      case EventView.profile:
        return _buildProfileView();
      case EventView.organize:
        return _buildOrganizeView(isEditing: false);
      case EventView.edit:
        return _buildOrganizeView(isEditing: true);
    }
  }

  Widget _buildExploreView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search events, locations...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isActive = category == _activeCategory;
              return ChoiceChip(
                label: Text(category),
                selected: isActive,
                onSelected: (_) => setState(() => _activeCategory = category),
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _categories.length,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<EventModel>>(
            stream: _eventsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to load events.',
                  subtitle: 'Please check your connection and try again.',
                );
              }

              final events = _filteredEventsFrom(snapshot.data ?? []);
              if (events.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.search,
                  title: 'No events found for your criteria.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _buildEventCard(event);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event) {
    return GestureDetector(
      onTap: () => _openEvent(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildEventImage(event.imageUrl, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        event.date,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const Spacer(),
                      Text(
                        event.price > 0
                            ? 'RM ${event.price.toStringAsFixed(2)}'
                            : 'FREE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final event = _selectedEvent;
    if (event == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildEventImage(event.imageUrl, fit: BoxFit.cover),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white70,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _selectView(EventView.explore),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'DATE',
                  value: event.date,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.location_on,
                  label: 'LOCATION',
                  value: event.location,
                ),
                const SizedBox(height: 16),
                const Text(
                  'About Event',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (event.organizerName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Organized by ${event.organizerName}',
                    style: const TextStyle(color: Colors.black45),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price per ticket',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        event.price > 0
                            ? 'RM ${event.price.toStringAsFixed(2)}'
                            : 'FREE',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinEvent(event),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(event.price > 0 ? 'Buy Ticket' : 'Register Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketsView() {
    if (_tickets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.confirmation_number,
        title: 'No Active Tickets',
        subtitle: 'Join events from the explore page to see them here.',
        actionLabel: 'Explore Events',
        onAction: () => _selectView(EventView.explore),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildManageView() {
    if (!_isOrganizer) {
      return _buildEmptyState(
        icon: Icons.lock_outline,
        title: 'Organizer access required.',
        subtitle: 'Please login as an organizer to manage events.',
        actionLabel: 'Back to Login',
        onAction: () => _selectView(EventView.auth),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Organizer Dashboard',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _openProfile,
                    icon: const Icon(Icons.person_outline),
                  ),
                  ElevatedButton.icon(
                    onPressed: _startNewEvent,
                    icon: const Icon(Icons.add),
                    label: const Text('Post Event'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<EventModel>>(
            stream: _eventsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to load your events.',
                );
              }
              final events = (snapshot.data ?? []).where((event) {
                final matchesId =
                    _currentUserId != null && event.organizerId == _currentUserId;
                final matchesName =
                    event.organizerName.isNotEmpty &&
                    event.organizerName == _currentUserName;
                return matchesId || matchesName;
              }).toList();
              if (events.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.event_busy,
                  title: 'No events yet.',
                  subtitle: 'Create your first event to get started.',
                  actionLabel: 'Post Event',
                  onAction: _startNewEvent,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 70,
                            height: 70,
                            child: _buildEventImage(event.imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By ${event.organizerName}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.price > 0
                                    ? 'RM ${event.price.toStringAsFixed(2)}'
                                    : 'FREE',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _startEditingEvent(event),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () => _deleteEvent(event.id),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    if (!_isOrganizer) {
      return _buildEmptyState(
        icon: Icons.lock_outline,
        title: 'Organizer access required.',
        subtitle: 'Please login as an organizer to update your profile.',
        actionLabel: 'Back to Login',
        onAction: () => _selectView(EventView.auth),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _selectView(EventView.manage),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 4),
              const Text(
                'Organizer Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _profileNameController,
            label: 'Organization Name',
            hint: 'Enter organization name',
            prefixIcon: Icons.apartment,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdatingProfile ? null : _handleUpdateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isUpdatingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Profile Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(TicketModel ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.event.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Joined on ${ticket.purchaseDate}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _cancelTicket(ticket.ticketId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
          _buildQrPlaceholder(ticket.ticketId),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(ticket.event.date),
                const SizedBox(width: 16),
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(ticket.event.location)),
                Text(
                  ticket.event.price > 0
                      ? 'RM ${ticket.event.price.toStringAsFixed(2)}'
                      : 'FREE',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPlaceholder(String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: GridView.builder(
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (context, index) {
                final random = Random(index + value.hashCode);
                return Container(
                  decoration: BoxDecoration(
                    color: random.nextBool() ? Colors.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizeView({required bool isEditing}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _selectView(
                    _isOrganizer ? EventView.manage : EventView.explore),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 4),
              Text(
                isEditing ? 'Update Event' : 'Publish New Event',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _titleController,
            label: 'Event Title*',
            hint: 'Give your event a clear name',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Category*',
                  value: _newEventCategory,
                  items: _categories.where((item) => item != 'All').toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _newEventCategory = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: 'Date*',
                  value: _newEventDate,
                  onPressed: _selectDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showNewCategoryField = true),
              icon: const Icon(Icons.add),
              label: const Text('Add new category'),
            ),
          ),
          if (_showNewCategoryField) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _newCategoryController,
                    label: 'New Category',
                    hint: 'e.g. Adventure',
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addNewCategory,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildTextField(
            controller: _locationController,
            label: 'Location*',
            hint: 'Where is the venue?',
            prefixIcon: Icons.location_on,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _priceController,
            label: 'Price (RM)',
            hint: '0.00 (leave 0 for free)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Tell travelers what to expect...',
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _buildImagePickerField(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : _publishEvent,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(
                _isPublishing
                    ? 'Publishing...'
                    : isEditing
                        ? 'Update Event'
                        : 'Publish Event',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(
                  value.isEmpty ? 'Select date' : value,
                  style: TextStyle(
                    color: value.isEmpty ? Colors.black38 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerField() {
    final previewImage =
        _newEventImageRef ?? _fallbackImageRefForCategory(_newEventCategory);
    final pickedImageFile = _newEventImageFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Image',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _pickEventImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            pickedImageFile == null
                ? 'Select from album'
                : 'Change image',
          ),
        ),
        if (pickedImageFile != null) ...[
          const SizedBox(height: 6),
          Text(
            pickedImageFile.name,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _newEventImageRef,
          hint: const Text('Use category default'),
          items: _eventImageOptions
              .map(
                (item) => DropdownMenuItem<String?>(
                  value: item,
                  child: Text(_imageLabelFromPath(item)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _newEventImageRef = value;
            _newEventImageFile = null;
          }),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: pickedImageFile != null
                ? Image.file(File(pickedImageFile.path), fit: BoxFit.cover)
                : previewImage == null
                    ? const Center(
                        child: Text(
                          'No image selected',
                          style: TextStyle(color: Colors.black45),
                        ),
                      )
                    : _buildEventImage(previewImage, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.black12),
            const SizedBox(height: 16),
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
                subtitle,
                style: const TextStyle(color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    if (!_isLoggedIn) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.search,
            label: 'Explore',
            isActive: _view == EventView.explore || _view == EventView.detail,
            onTap: () => _selectView(EventView.explore),
          ),
          if (_isOrganizer)
            _buildNavItem(
              icon: Icons.settings,
              label: 'Manage',
              isActive: _view == EventView.manage ||
                  _view == EventView.organize ||
                  _view == EventView.edit,
              onTap: () => _selectView(EventView.manage),
            )
          else
            _buildNavItem(
              icon: Icons.confirmation_number,
              label: 'My Tickets',
              isActive: _view == EventView.tickets,
              onTap: () => _selectView(EventView.tickets),
              badgeCount: _tickets.length,
            ),
          _buildNavItem(
            icon: Icons.logout,
            label: 'Logout',
            isActive: false,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(icon, color: isActive ? Colors.blue : Colors.black38),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.blue : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
