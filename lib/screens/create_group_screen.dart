import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/group_chat_service.dart';
import 'package:whatsup/helpers/image_picker_helper.dart';
import 'package:whatsup/helpers/image_uploader.dart';
import 'package:whatsup/widgets/ui/colors.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  List<Map<dynamic, dynamic>> searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final loggedInuserId = FirebaseAuth.instance.currentUser!.uid;
  final List<String> selectedMembersIds = [];
  final List<String> selectedMembersNames = [];
  bool isLoading = false;
  File? _groupImage;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickGroupImage() async {
    final file = await pickImage(context);
    if (file == null) return;
    setState(() {
      _groupImage = file;
    });
  }

  void _searchUsers() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FirebaseDatabase.instance
        .ref('users')
        .get()
        .then((snapshot) {
          final allUsers = snapshot.value as Map<dynamic, dynamic>;
          final results = allUsers.values
              .where(
                (user) =>
                    user['uid'] != loggedInuserId &&
                    user['profilename'].toString().toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();

          setState(() {
            searchResults = List<Map<dynamic, dynamic>>.from(results);
          });
        })
        .catchError((error) {
          print("Error searching users: $error");
        });
  }

  void _addSelectedMember(String uid, String name) {
    setState(() {
      selectedMembersIds.add(uid);
      selectedMembersNames.add(name);
    });
  }

  void _removeSelectedMember(String uid, String name) {
    setState(() {
      selectedMembersIds.remove(uid);
      selectedMembersNames.remove(name);
    });
  }

  Future<void> _createGroup() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showSnack('Please add a title');
      return;
    }

    if (_groupImage == null) {
      _showSnack('Please select a group image');
      return;
    }

    if (selectedMembersIds.isEmpty) {
      _showSnack('Please add members');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final members = {
        ...selectedMembersIds,
        loggedInuserId,
      }.toList();

      final bytes = await _groupImage!.readAsBytes();
      final imageUrl = await uploadImage(
        bytes,
        'group_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (imageUrl == null) {
        _showSnack('Unable to upload image. Please try again.');
        return;
      }

      final groupData = {
        'name': title,
        'creatorId': loggedInuserId,
        'memberIds': members,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'image_url': imageUrl,
      };

      final isCreated = await GroupChatService.createGroup(groupData);
      if (isCreated && mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      _showSnack('Unable to create group: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Widget> getNameBadges() {
    var i = 0;
    final List<Widget> badges = [];
    selectedMembersNames.forEach((name) {
      badges.add(
        Badge(
          label: Row(
            children: [
              Text(name, style: TextStyle(fontSize: 14)),
              SizedBox(width: 20),
              IconButton(
                onPressed: () {
                  _removeSelectedMember(selectedMembersIds[i], name);
                },
                icon: Icon(Icons.cancel_rounded, color: kwhiteColor),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      i++;
    });
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text("Create Group"),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: 80,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: isLoading ? null : _createGroup,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text("Title:", style: TextStyle(fontSize: 20)),
              SizedBox(height: 15),
              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : _pickGroupImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _groupImage != null
                            ? FileImage(_groupImage!)
                            : const AssetImage(
                                    'assets/images/default_group_avatar.png',
                                  )
                                as ImageProvider,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Add Group Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Text("Select Members:", style: TextStyle(fontSize: 20)),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by username or email',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _searchUsers();
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Wrap(
                spacing: 8, // horizontal space between badges
                runSpacing: 8, // vertical space between lines
                children: getNameBadges(),
              ),
              SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final user = searchResults[index];
                    final isAlreadySelected = selectedMembersIds.contains(
                      user["uid"],
                    );

                    return ListTile(
                      tileColor: isAlreadySelected
                          ? Theme.of(context).colorScheme.primary
                          : kwhiteColor,
                      textColor: isAlreadySelected ? kwhiteColor : kblackColor,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            (user['image_url'] != null &&
                                user['image_url'] is String &&
                                user['image_url'].isNotEmpty)
                            ? NetworkImage(user['image_url'])
                            : const AssetImage(
                                    'assets/images/default_avatar.png',
                                  )
                                  as ImageProvider,
                      ),
                      title: Text(user['profilename'] ?? 'No Name'),
                      subtitle: Text(user['email'] ?? 'No Email'),
                      onTap: () => {
                        if (isAlreadySelected)
                          {
                            _removeSelectedMember(
                              user['uid'],
                              user['profilename'],
                            ),
                          }
                        else
                          {
                            _addSelectedMember(
                              user['uid'],
                              user['profilename'],
                            ),
                          },
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
