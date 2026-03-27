import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('[REGISTER] Continue pressed');
    debugPrint('[REGISTER] Full name: "${_nameController.text.trim()}"');
    debugPrint('[REGISTER] National ID: "${_idController.text.trim()}"');
    debugPrint('[REGISTER] Phone: "${_phoneController.text.trim()}"');

    final isValid = _formKey.currentState!.validate();
    debugPrint('[REGISTER] Form valid: $isValid');

    if (isValid) {
      debugPrint('[REGISTER] Dispatching AuthRegisterSubmitted');
      context.read<AuthBloc>().add(AuthRegisterSubmitted(
            fullName: _nameController.text.trim(),
            nationalId: _idController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const AuthHeader(),
                const SizedBox(height: 48),
                Text('Create your account',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Fill in your details to get started',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
                _buildField(_nameController, 'Full Name', Icons.person),
                const SizedBox(height: 16),
                _buildField(_idController, 'National ID', Icons.badge),
                const SizedBox(height: 16),
                _buildField(_phoneController, 'Phone Number', Icons.phone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
