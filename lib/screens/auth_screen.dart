import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/widgets/image_picker.dart';
import 'package:whatsup/widgets/ui/buttons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  var _isLogin = true;
  var formKey = GlobalKey<FormState>();

  var _userName = "";
  var _email = "";
  var _password = "";
  File? _pickedImage;
  var _isLoading = false;

  void _submitForm() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!_isLogin && _pickedImage == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please pick an image.')));
      return;
    }

    formKey.currentState!.save();

    try {
      setState(() {
        _isLoading = true;
      });
      late bool hasError;
      if (_isLogin) {
        hasError = await AuthService.login(_email, _password, context);
      } else {
        hasError = await AuthService.signUp(
          _email,
          _password,
          _pickedImage!,
          _userName,
          context,
        );
      }
      if (!hasError) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));

        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _pickImage(File pickedImage) {
    _pickedImage = pickedImage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLogin) ...{
                      ImagePickerWidget(onPickImage: _pickImage),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "User Name",
                        ),
                        onSaved: (value) => _userName = value!,
                        validator: (value) =>
                            value != null && value.trim().length > 4
                            ? null
                            : "Please enter at least 5 characters.",
                      ),
                      const SizedBox(height: 10),
                    },
                    TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Email"),
                      onSaved: (value) => _email = value!,
                      validator: (value) => value != null && value.contains("@")
                          ? null
                          : "Please enter a valid email address.",
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Password"),
                      obscureText: true,
                      onSaved: (value) => _password = value!,
                      validator: (value) =>
                          value != null && value.trim().length > 6
                          ? null
                          : "Please enter at least 7 characters.",
                    ),
                    const SizedBox(height: 20),
                    Buttons.primary(
                      _isLogin ? "Login" : "Sign Up",
                      _submitForm,
                      _isLoading,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Login",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
