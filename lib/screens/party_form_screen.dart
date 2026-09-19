import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/indian_states.dart';
import '../models/party.dart';
import '../services/party_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class PartyFormScreen extends StatefulWidget {
  const PartyFormScreen({super.key, this.party});

  final Party? party;

  bool get isEditing => party != null;

  @override
  State<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends State<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _partyService = PartyService();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstinController;
  late final TextEditingController _emailController;

  String? _selectedState;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final party = widget.party;
    _nameController = TextEditingController(text: party?.name ?? '');
    _mobileController = TextEditingController(text: party?.mobile ?? '');
    _addressController = TextEditingController(text: party?.address ?? '');
    _gstinController = TextEditingController(text: party?.gstin ?? '');
    _emailController = TextEditingController(text: party?.email ?? '');
    _selectedState = party?.state;
    if (_selectedState != null && !IndianStates.all.contains(_selectedState)) {
      // Keep custom/legacy state value visible in dropdown.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null || _selectedState!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await _partyService.updateParty(
          widget.party!.copyWith(
            name: _nameController.text,
            mobile: _mobileController.text,
            address: _addressController.text,
            state: _selectedState!,
            gstin: _gstinController.text,
            email: _emailController.text,
          ),
        );
      } else {
        await _partyService.addParty(
          name: _nameController.text,
          mobile: _mobileController.text,
          address: _addressController.text,
          state: _selectedState!,
          gstin: _gstinController.text,
          email: _emailController.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Party updated' : 'Party added',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save party: $error'),
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Party' : 'Add Party'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Party name *',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Party name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mobileController,
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
                  labelText: 'State *',
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
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedState = value),
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'State'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _gstinController,
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
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
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
                    : Text(widget.isEditing ? 'Update Party' : 'Save Party'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
