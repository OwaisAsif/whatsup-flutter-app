import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/helpers/image_uploader.dart';

final firebase = FirebaseAuth.instance;
final _db = FirebaseDatabase.instance;

class AuthService {
  static Future<bool> login(
    String _email,
    String _password,
    BuildContext context,
  ) async {
    try {
      await firebase.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  static Future<bool> signUp(
    String _email,
    String _password,
    File _pickedImage,
    String _userName,
    BuildContext context,
  ) async {
    try {
      await firebase.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      final uploadedImageUrl = await uploadImage(
        _pickedImage.readAsBytesSync(),
        firebase.currentUser!.uid,
      );

      _db.ref("users/${firebase.currentUser!.uid}").set({
        "uid": firebase.currentUser!.uid,
        "username": _userName,
        "email": _email,
        "image_url": uploadedImageUrl,
      });

      return true;
    } on FirebaseAuthException catch (error) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  static Future<bool> completeUserDetails(
    String uid,
    Map<String, Object?> userData,
    BuildContext context,
  ) async {
    try {
      _db.ref('users/$uid').update(userData);
      return true;
    } on FirebaseException catch (error) {
      debugPrint("Error saving user data: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save data: ${error.message}')),
      );
      return false;
    }
  }

  static Future<bool> checkUserNameAvailability(String name) async {
    try {
      final event = await _db
          .ref('users')
          .orderByChild('profilename')
          .equalTo(name.trim())
          .once();

      // No casting needed → prevents type crash
      if (event.snapshot.exists) {
        return true;
      }

      return false; // unique profile name
    } catch (error) {
      return false;
    }
  }

  static Future<Map<dynamic, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        return snapshot.value as Map;
      } else {
        debugPrint('User data invalid or not found: ${snapshot.value}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return null;
    }
  }
}
