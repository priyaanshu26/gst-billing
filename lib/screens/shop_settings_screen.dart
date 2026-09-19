import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/indian_states.dart';
import '../models/shop_config.dart';
import '../services/session_service.dart';
import '../services/shop_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key, this.embedded = false});

  /// When true, this screen is a bottom-nav tab and must not pop the shell.
  final bool embedded;

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopConfigService = ShopConfigService();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedState;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _canEdit => SessionService.instance.canManageShop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_loading) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final config = await _shopConfigService.getOrCreateDefault();
      if (!mounted) return;
      setState(() {
        _nameController.text = config.shopName;
        _mobileController.text = config.mobile;
        _emailController.text = config.email;
        _gstinController.text = config.gstin;
        _addressController.text = config.address;
        _selectedState = config.state.isEmpty ? null : config.state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null || _selectedState!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your shop state')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _shopConfigService.saveShopConfig(
        ShopConfig(
          shopName: _nameController.text.trim(),
          address: _addressController.text.trim(),
          state: _selectedState!,
          gstin: _gstinController.text.trim().toUpperCase(),
          mobile: _mobileController.text.trim(),
          email: _emailController.text.trim(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop details saved')),
      );
      if (!widget.embedded) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save shop details: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateItems = <String>{
      ...IndianStates.all,
      if (_selectedState != null && _selectedState!.isNotEmpty) _selectedState!,
    }.toList()
      ..sort();

    return Scaffold(
      primary: !widget.embedded,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(_canEdit ? 'Shop Settings' : 'Shop Details'),
            ),
      body: SafeArea(
        top: !widget.embedded,
        bottom: !widget.embedded,
        child: _buildBody(stateItems),
      ),
    );
  }

  Widget _buildBody(List<String> stateItems) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load shop details.\n$_loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_canEdit) ...[
            Card(
              color: AppTheme.primary.withValues(alpha: 0.06),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Staff can view shop details but cannot change them. '
                  'Ask the shop owner to update these fields.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'These details appear as the header on every PDF invoice. '
                'The shop state decides whether a bill is taxed as '
                'CGST + SGST or IGST.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameController,
            enabled: _canEdit && !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Shop name *',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: (value) =>
                Validators.requiredField(value, fieldName: 'Shop name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mobileController,
            enabled: _canEdit && !_saving,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile',
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              if (value.trim().length != 10) {
                return 'Enter a 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            enabled: _canEdit && !_saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              if (!value.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedState,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Shop state *',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: stateItems
                .map(
                  (state) => DropdownMenuItem(
                    value: state,
                    child: Text(
                      state,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                )
                .toList(),
            onChanged: (!_canEdit || _saving)
                ? null
                : (value) => setState(() => _selectedState = value),
            validator: (value) =>
                Validators.requiredField(value, fieldName: 'Shop state'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _gstinController,
            enabled: _canEdit && !_saving,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(15),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: const InputDecoration(
              labelText: 'GSTIN',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              if (value.trim().length != 15) {
                return 'GSTIN must be 15 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressController,
            enabled: _canEdit && !_saving,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Shop Details'),
            ),
          ],
        ],
      ),
    );
  }
}
