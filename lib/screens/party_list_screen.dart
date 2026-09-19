import 'package:flutter/material.dart';

import '../models/party.dart';
import '../services/party_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_refresh_builder.dart';
import 'party_bill_history_screen.dart';
import 'party_form_screen.dart';

class PartyListScreen extends StatefulWidget {
  const PartyListScreen({super.key});

  @override
  State<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends State<PartyListScreen> {
  final _partyService = PartyService();
  final _searchController = TextEditingController();
  String _query = '';
  int _reload = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadList() {
    if (mounted) setState(() => _reload++);
  }

  Future<void> _openForm({Party? party}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartyFormScreen(party: party),
      ),
    );
    _reloadList();
  }

  Future<void> _openHistory(Party party) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartyBillHistoryScreen(party: party),
      ),
    );
    _reloadList();
  }

  Future<void> _confirmDelete(Party party) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete party?'),
          content: Text(
            'Delete "${party.name}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _partyService.deleteParty(party.partyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${party.name} deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = SessionService.instance.canManageShop;

    return Scaffold(
      primary: false,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'fab_parties',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Party'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, mobile, GSTIN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: LiveRefreshBuilder<List<Party>>(
              key: ValueKey(_reload),
              load: _partyService.getParties,
              listen: _partyService.watchParties,
              errorTitle: 'Could not load parties.',
              builder: (context, allParties) {
                final parties = _partyService.filterParties(allParties, _query);

                if (parties.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? canManage
                                ? 'No parties yet.\nTap Add Party to create one.'
                                : 'No parties yet.\nAsk the shop owner to add one.'
                            : 'No parties match your search.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: parties.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final party = parties[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.primary,
                          child: Text(
                            party.name.isNotEmpty
                                ? party.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          party.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (party.mobile.isNotEmpty) party.mobile,
                            party.state,
                            if (party.gstin.isNotEmpty) party.gstin,
                          ].join(' · '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'history') {
                              _openHistory(party);
                            } else if (value == 'edit') {
                              _openForm(party: party);
                            } else if (value == 'delete') {
                              _confirmDelete(party);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'history',
                              child: Text('Bill history'),
                            ),
                            if (canManage) ...const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.danger),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => _openHistory(party),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
