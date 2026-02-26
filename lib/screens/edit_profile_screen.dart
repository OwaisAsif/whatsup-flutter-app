import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _selectedGender;
  String? _initialProfileName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final profile = await AuthService.getUserProfile(uid);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _initialProfileName = profile?['profilename']?.toString();
      _profileNameController.text = profile?['profilename']?.toString() ?? '';
      _phoneController.text = profile?['phone']?.toString() ?? '';
      _ageController.text = profile?['age']?.toString() ?? '';
      _bioController.text = profile?['bio']?.toString() ?? '';
      _selectedGender = profile?['gender']?.toString();
    });
  }

  Future<void> _saveProfile() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final newName = _profileNameController.text.trim();
    if (newName.isEmpty) {
      _showSnack('Profile name is required');
      return;
    }

    if (_selectedGender == null) {
      _showSnack('Select a gender');
      return;
    }

    if (newName != (_initialProfileName ?? '')) {
      final exists = await AuthService.checkUserNameAvailability(newName);
      if (exists) {
        _showSnack('Profile name already exists');
        return;
      }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSaving = true;
    });

    final payload = {
      'profilename': newName,
      'phone': _phoneController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'gender': _selectedGender,
      'bio': _bioController.text.trim(),
      'info_completed': true,
    };

    final success = await AuthService.completeUserDetails(
      uid,
      payload,
      context,
    );
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _initialProfileName = newName;
    });

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  void _selectGender(String gender) {
    setState(() {
      _selectedGender = gender;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _profileNameController,
                      decoration: const InputDecoration(
                        labelText: 'Profile Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter profile name';
                        }
                        if (value.trim().length < 3) {
                          return 'Must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter phone number';
                        }
                        if (value.trim().length < 10) {
                          return 'Enter valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final age = int.tryParse(value ?? '');
                        if (age == null) {
                          return 'Enter a valid age';
                        }
                        if (age < 10 || age > 100) {
                          return 'Age must be between 10 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _GenderChip(
                          label: 'Male',
                          icon: Icons.male_outlined,
                          selected: _selectedGender == 'Male',
                          onTap: () => _selectGender('Male'),
                        ),
                        const SizedBox(width: 12),
                        _GenderChip(
                          label: 'Female',
                          icon: Icons.female_outlined,
                          selected: _selectedGender == 'Female',
                          onTap: () => _selectGender('Female'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell something about yourself...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your bio';
                        }
                        if (value.trim().length < 10) {
                          return 'Bio must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
