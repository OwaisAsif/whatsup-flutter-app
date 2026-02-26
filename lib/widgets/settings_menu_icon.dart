import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/screens/create_group_screen.dart';
import 'package:whatsup/screens/settings_screen.dart';
import 'package:whatsup/widgets/ui/colors.dart';

class SettingsMenuIcon extends StatelessWidget {
  const SettingsMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          );
        } else if (value == 'create_group') {
          // create group logic
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGroupScreen()),
          );
        } else if (value == 'logout') {
          FirebaseAuth.instance.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 18, color: kblackColor),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'create_group',
          child: Row(
            children: [
              Icon(Icons.group_add, size: 18, color: kblackColor),
              SizedBox(width: 8),
              Text('Create Group'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: kblackColor),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
        ),
      ],
    );
  }
}
