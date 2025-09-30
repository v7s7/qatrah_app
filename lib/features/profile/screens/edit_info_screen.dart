import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/profile_provider.dart';
import '../models/profile.dart';

class EditInfoScreen extends ConsumerStatefulWidget {
  const EditInfoScreen({super.key});
  @override
  ConsumerState<EditInfoScreen> createState() => _EditInfoState();
}

class _EditInfoState extends ConsumerState<EditInfoScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncP = ref.watch(profileProvider);
    if (asyncP.hasValue && !_loaded) {
      final p = asyncP.value!;
      _name.text = p.name;
      _email.text = p.email;
      _phone.text = p.phone;
      _username.text = p.username;
      _loaded = true;
    }
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Edit Info'),
        backgroundColor: Colors.black.withOpacity(0.15),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _field('Name', _name),
              const SizedBox(height: 10),
              _field('Email', _email),
              const SizedBox(height: 10),
              _field('Phone Number', _phone),
              const SizedBox(height: 10),
              _field('Username', _username),
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final p = Profile(
                      name: _name.text,
                      email: _email.text,
                      phone: _phone.text,
                      username: _username.text,
                    );
                    await ref.read(saveProfileProvider(p).future);
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
    ),
  );
}
