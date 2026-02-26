import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/screens/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<dynamic, dynamic>> searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final loggedInuserId = FirebaseAuth.instance.currentUser!.uid;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by username or email',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      _searchUsers();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final user = searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          (user['image_url'] != null &&
                              user['image_url'] is String &&
                              user['image_url'].isNotEmpty)
                          ? NetworkImage(user['image_url'])
                          : const AssetImage('assets/images/default_avatar.png')
                                as ImageProvider,
                    ),
                    title: Text(user['profilename'] ?? 'No Name'),
                    subtitle: Text(user['email'] ?? 'No Email'),
                    onTap: () => {
                      print(
                        "Tapped on user: ${user['profilename']} with uid: ${user['uid']}",
                      ),
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            id: loggedInuserId,
                            contactId: user['uid'],
                            isGroup: false,
                          ),
                        ),
                      ),
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
