import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/firebase/chat_service.dart';
import 'package:whatsup/firebase/group_chat_service.dart';
import 'package:whatsup/helpers/image_picker_helper.dart';
import 'package:whatsup/helpers/image_uploader.dart';

class ChatDetailsScreen extends StatefulWidget {
  const ChatDetailsScreen({
    super.key,
    required this.contactId,
    required this.isGroup,
  });

  final String contactId;
  final bool isGroup;

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  bool _isLoading = true;
  Map<dynamic, dynamic>? _details;
  List<Map<dynamic, dynamic>> _memberProfiles = const [];
  List<String> _memberIds = const [];
  String? _currentUserId;
  bool _isBlocked = false;
  bool _mutatingBlock = false;
  bool _groupActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
    });

    Map<dynamic, dynamic>? details;
    List<Map<dynamic, dynamic>> members = [];
    List<String> memberIds = const [];

    if (widget.isGroup) {
      details = await GroupChatService.getGroupData(widget.contactId);
      memberIds =
          (details?['memberIds'] as List?)
              ?.map((id) => id.toString())
              .toList() ??
          [];
      if (memberIds.isNotEmpty) {
        final fetched = await Future.wait(
          memberIds.map((id) => AuthService.getUserProfile(id)),
        );
        members = fetched.whereType<Map<dynamic, dynamic>>().toList();
      }
    } else {
      details = await AuthService.getUserProfile(widget.contactId);
      memberIds = const [];
    }

    bool blocked = _isBlocked;
    if (!widget.isGroup && _currentUserId != null) {
      blocked = await ChatService.isUserBlocked(
        _currentUserId!,
        widget.contactId,
      );
    }

    if (!mounted) return;
    setState(() {
      _details = details;
      _memberProfiles = members;
      _isLoading = false;
      _isBlocked = blocked;
      _memberIds = memberIds;
    });
  }

  Widget _buildAvatar() {
    if (widget.isGroup) {
      final imageUrl = _details?['image_url']?.toString();
      final provider = (imageUrl != null && imageUrl.isNotEmpty)
          ? NetworkImage(imageUrl) as ImageProvider
          : const AssetImage('assets/images/default_group_avatar.png');
      return CircleAvatar(radius: 38, backgroundImage: provider);
    }
    final imageUrl = _details?['image_url']?.toString();
    final provider = (imageUrl != null && imageUrl.isNotEmpty)
        ? NetworkImage(imageUrl) as ImageProvider
        : const AssetImage('assets/images/default_avatar.png');
    return CircleAvatar(radius: 38, backgroundImage: provider);
  }

  String _titleText() {
    if (widget.isGroup) {
      return (_details?['name'] ?? 'Group Chat').toString();
    }
    return (_details?['profilename'] ?? _details?['username'] ?? 'User')
        .toString();
  }

  List<Widget> _buildUserFields() {
    if (widget.isGroup) return const [];
    final phone = _details?['phone']?.toString();
    final age = _details?['age']?.toString();
    final gender = _details?['gender']?.toString();
    final bio = _details?['bio']?.toString();
    final email = _details?['email']?.toString();

    final tiles = <Widget>[];
    if (email != null && email.isNotEmpty) {
      tiles.add(_InfoTile(label: 'Email', value: email));
    }
    if (phone != null && phone.isNotEmpty) {
      tiles.add(_InfoTile(label: 'Phone', value: phone));
    }
    if (age != null && age.isNotEmpty) {
      tiles.add(_InfoTile(label: 'Age', value: age));
    }
    if (gender != null && gender.isNotEmpty) {
      tiles.add(_InfoTile(label: 'Gender', value: gender));
    }
    if (bio != null && bio.isNotEmpty) {
      tiles.add(_InfoTile(label: 'Bio', value: bio));
    }
    return tiles;
  }

  List<Widget> _buildGroupMembers() {
    if (!widget.isGroup || _memberProfiles.isEmpty) return const [];
    final members = _memberProfiles
        .map(
          (member) => ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (member['image_url'] != null &&
                      member['image_url'] is String &&
                      member['image_url'].isNotEmpty)
                  ? NetworkImage(member['image_url']) as ImageProvider
                  : const AssetImage('assets/images/default_avatar.png'),
            ),
            title: Text(
              member['profilename'] ?? member['username'] ?? 'Unknown',
            ),
            subtitle: Text(member['email'] ?? ''),
          ),
        )
        .toList();
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          'Members (${members.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      ...members,
    ];
  }

  bool get _isGroupOwner =>
      widget.isGroup && _details?['creatorId']?.toString() == _currentUserId;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleBlock() async {
    if (_currentUserId == null || _mutatingBlock || widget.isGroup) return;
    setState(() {
      _mutatingBlock = true;
    });
    try {
      if (_isBlocked) {
        await ChatService.unblockUser(_currentUserId!, widget.contactId);
      } else {
        await ChatService.blockUser(_currentUserId!, widget.contactId);
      }
      if (!mounted) return;
      setState(() {
        _isBlocked = !_isBlocked;
      });
    } catch (error) {
      _showSnack('Unable to update block status: $error');
    } finally {
      if (mounted) {
        setState(() {
          _mutatingBlock = false;
        });
      }
    }
  }

  Future<void> _changeGroupImage() async {
    if (!widget.isGroup || !_isGroupOwner || _groupActionInProgress) return;
    final file = await pickImage(context);
    if (file == null) return;
    setState(() {
      _groupActionInProgress = true;
    });
    try {
      final bytes = await file.readAsBytes();
      final url = await uploadImage(bytes, 'group_${widget.contactId}');
      if (url == null) {
        _showSnack('Image upload failed');
        return;
      }
      await GroupChatService.updateGroupImageUrl(widget.contactId, url);
      await _loadDetails();
    } catch (error) {
      _showSnack('Unable to update group photo: $error');
    } finally {
      if (mounted) {
        setState(() {
          _groupActionInProgress = false;
        });
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    if (!widget.isGroup || _groupActionInProgress) return;
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter email or profile name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;

    setState(() {
      _groupActionInProgress = true;
    });
    try {
      final newMemberId = await _findUserIdByQuery(query);
      if (newMemberId == null) {
        _showSnack('No user found for "$query"');
        return;
      }
      if (_memberIds.contains(newMemberId)) {
        _showSnack('User is already in this group');
        return;
      }
      await GroupChatService.addMembers(widget.contactId, [newMemberId]);
      await _loadDetails();
      _showSnack('Member added');
    } catch (error) {
      _showSnack('Unable to add member: $error');
    } finally {
      if (mounted) {
        setState(() {
          _groupActionInProgress = false;
        });
      }
    }
  }

  Future<String?> _findUserIdByQuery(String query) async {
    if (query.isEmpty) return null;
    final normalized = query.trim().toLowerCase();
    final snapshot = await FirebaseDatabase.instance.ref('users').get();
    if (!snapshot.exists || snapshot.value is! Map) return null;
    final users = snapshot.value as Map<dynamic, dynamic>;
    for (final entry in users.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == null || value is! Map) continue;
      final map = value as Map<dynamic, dynamic>;
      final email = map['email']?.toString().toLowerCase();
      final profile = map['profilename']?.toString().toLowerCase();
      if (email == normalized || profile == normalized) {
        return key.toString();
      }
    }
    return null;
  }

  Future<void> _leaveGroup() async {
    if (!widget.isGroup || _currentUserId == null || _groupActionInProgress) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _groupActionInProgress = true;
    });
    try {
      await GroupChatService.removeMember(widget.contactId, _currentUserId!);
      if (!mounted) return;
      _showSnack('You left the group');
      Navigator.of(context).pop(true);
    } catch (error) {
      _showSnack('Unable to leave group: $error');
    } finally {
      if (mounted) {
        setState(() {
          _groupActionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGroup ? 'Group Details' : 'Contact Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          _buildAvatar(),
                          const SizedBox(height: 12),
                          Text(
                            _titleText(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (!widget.isGroup)
                            Text(
                              _details?['email']?.toString() ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          if (widget.isGroup)
                            Text(
                              '${(_details?['memberIds'] as List?)?.length ?? 0} members',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isGroup)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _isBlocked
                              ? Icons.lock_open_outlined
                              : Icons.block_outlined,
                        ),
                        title: Text(_isBlocked ? 'Unblock user' : 'Block user'),
                        subtitle: Text(
                          _isBlocked
                              ? 'Allow this user to contact you again'
                              : 'Stop receiving messages and calls',
                        ),
                        trailing: _mutatingBlock
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _mutatingBlock ? null : _toggleBlock,
                      ),
                    ),
                  if (widget.isGroup)
                    Card(
                      child: Column(
                        children: [
                          if (_isGroupOwner)
                            ListTile(
                              leading: const Icon(Icons.camera_alt_outlined),
                              title: const Text('Change group photo'),
                              trailing: _groupActionInProgress
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _groupActionInProgress
                                  ? null
                                  : _changeGroupImage,
                            ),
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1),
                            title: const Text('Add member'),
                            trailing: _groupActionInProgress
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: _groupActionInProgress
                                ? null
                                : _showAddMemberDialog,
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(
                              Icons.logout,
                              color: Colors.red,
                            ),
                            title: const Text(
                              'Leave group',
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: _groupActionInProgress ? null : _leaveGroup,
                          ),
                        ],
                      ),
                    ),
                  ..._buildUserFields(),
                  ..._buildGroupMembers(),
                  if (_details == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No details available.')),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(value),
      ),
    );
  }
}
