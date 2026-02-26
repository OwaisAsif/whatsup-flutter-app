import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/widgets/ui/buttons.dart';

class CompleteUserInformationScreen extends StatefulWidget {
  const CompleteUserInformationScreen({super.key, required this.uid});

  final String uid;

  @override
  State<CompleteUserInformationScreen> createState() =>
      _CompleteUserInformationScreenState();
}

class _CompleteUserInformationScreenState
    extends State<CompleteUserInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _profilenameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  String? _selectedGender;

  void _selectGender(String gender) {
    setState(() {
      _selectedGender = gender;
    });
  }

  void _submitForm() async {
    final isValid = _formKey.currentState!.validate();

    if (await checkNameInDatabase(_profilenameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name already exists')),
      );
      return;
    }

    if (!isValid || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final userData = {
      'profilename': _profilenameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'age': int.parse(_ageController.text.trim()),
      'gender': _selectedGender,
      'bio': _bioController.text.trim(),
      'info_completed': true,
    };

    final hasError = await AuthService.completeUserDetails(
      widget.uid,
      userData,
      context,
    );
    if (!hasError) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<bool> checkNameInDatabase(String? name) async {
    if (name == null || name.trim().isEmpty) return false;
    final isUnique = await AuthService.checkUserNameAvailability(name);
    return isUnique;
  }

  Widget _genderCard({required String gender, required IconData icon}) {
    final isSelected = _selectedGender == gender;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectGender(gender),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Colors.green.shade50 : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(height: 8),
              Text(
                gender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.green : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _profilenameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade200, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Complete Your Profile To Continue",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username
                      TextFormField(
                        controller: _profilenameController,
                        decoration: const InputDecoration(
                          labelText: "Profile Name",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter profile name';
                          }
                          if (value.trim().length < 3) {
                            return 'Profile name must be at least 3 characters use only letters and numbers and underscores';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Phone Number",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          if (value.length < 10) {
                            return 'Enter valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Age
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Age",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter age';
                          }
                          final age = int.tryParse(value);
                          if (age == null || age < 10 || age > 100) {
                            return 'Enter valid age';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gender
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Gender:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _genderCard(
                            gender: "Male",
                            icon: Icons.male_outlined,
                          ),
                          const SizedBox(width: 12),
                          _genderCard(
                            gender: "Female",
                            icon: Icons.female_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Bio TextArea (FIXED position)
                      TextFormField(
                        controller: _bioController,
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: "Bio",
                          hintText: "Tell something about yourself...",
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
                      const SizedBox(height: 20),

                      Buttons.primary("Continue", _submitForm, _isLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
