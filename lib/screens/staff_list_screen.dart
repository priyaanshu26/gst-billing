import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_refresh_builder.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _authService = AuthService();

  Future<void> _addStaff() async {
    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => const _StaffFormDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await _authService.createStaff(
        name: result.name,
        email: result.email,
        password: result.password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff account created')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authService.describeAuthError(error)),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _removeStaff(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove staff?'),
        content: Text(
          'Remove ${user.name} (${user.email}) from this shop? '
          'They will no longer be able to sign in to this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _authService.deleteStaff(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} removed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = SessionService.instance.requireShopId();

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
      body: LiveRefreshBuilder<List<AppUser>>(
        load: () => _authService.getShopUsers(shopId),
        listen: () => _authService.watchShopUsers(shopId),
        errorTitle: 'Could not load staff.',
        builder: (context, users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.isOwner
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : AppTheme.accent.withValues(alpha: 0.12),
                    foregroundColor:
                        user.isOwner ? AppTheme.primary : AppTheme.accent,
                    child: Icon(
                      user.isOwner
                          ? Icons.verified_user_outlined
                          : Icons.badge_outlined,
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${user.email}\n${UserRole.label(user.role)}',
                  ),
                  isThreeLine: true,
                  trailing: user.isStaff
                      ? IconButton(
                          tooltip: 'Remove staff',
                          onPressed: () => _removeStaff(user),
                          icon: const Icon(Icons.delete_outline),
                          color: AppTheme.danger,
                        )
                      : const Chip(label: Text('Owner')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StaffFormResult {
  const _StaffFormResult({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;
}

class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog();

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _StaffFormResult(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Temp password *',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
