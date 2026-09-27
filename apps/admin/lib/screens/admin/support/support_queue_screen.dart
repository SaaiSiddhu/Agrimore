// ADMR-62 — Support case queue.
//
// ADMR-61 built a real, tested backend (6 callables, 3 admin-only
// collections) with zero UI -- nothing in apps/admin could list, open or
// act on a support_cases document. This screen is that queue: filter by
// status or "my cases", using ADMR-61's own two real composite indexes
// (support_cases: status+updatedAt, and assignedTo+updatedAt) -- verified
// fresh against firestore.indexes.json before writing these queries, not
// assumed from an old summary. The two filters are mutually exclusive on
// purpose: combining "mine" with a specific status would need a third
// composite index that does not exist, so the UI simply never offers
// that combination rather than quietly under-fetching.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../widgets/paginated_query_list.dart';
import 'support_case_constants.dart';

class SupportQueueScreen extends StatefulWidget {
  const SupportQueueScreen({super.key, FirebaseFirestore? firestore, String? currentUid})
      : _firestoreOverride = firestore,
        _currentUidOverride = currentUid;
  final FirebaseFirestore? _firestoreOverride;

  /// Injectable so a widget test never needs a real signed-in
  /// FirebaseAuth user, mirroring [_firestoreOverride].
  final String? _currentUidOverride;

  @override
  State<SupportQueueScreen> createState() => _SupportQueueScreenState();
}

/// null = All, 'mine' = assigned to the current admin, otherwise a real
/// SUPPORT_CASE_STATUSES value.
class _SupportQueueScreenState extends State<SupportQueueScreen> {
  late final FirebaseFirestore _firestore =
      widget._firestoreOverride ?? FirebaseFirestore.instance;
  late final String? _currentUid =
      widget._currentUidOverride ?? FirebaseAuth.instance.currentUser?.uid;
  String? _filter;

  Query<Map<String, dynamic>> get _query {
    final base = _firestore.collection('support_cases');
    if (_filter == 'mine') {
      return base
          .where('assignedTo', isEqualTo: _currentUid ?? '')
          .orderBy('updatedAt', descending: true);
    }
    if (_filter != null) {
      return base
          .where('status', isEqualTo: _filter)
          .orderBy('updatedAt', descending: true);
    }
    return base.orderBy('updatedAt', descending: true);
  }

  Future<void> _createCase() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateCaseDialog(firestore: _firestore),
    );
    if (created == true && mounted) {
      SnackbarHelper.showSuccess(context, 'Case created');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Support Cases'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCase,
        icon: const Icon(Icons.add),
        label: const Text('New case'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip(null, 'All'),
                for (final s in kSupportCaseChangeableStatuses)
                  _filterChip(s, supportCaseStatusLabel(s)),
                _filterChip('resolved', 'Resolved'),
                _filterChip('mine', 'My cases'),
              ],
            ),
          ),
          Expanded(
            child: PaginatedQueryList(
              key: ValueKey('support-queue-${_filter ?? 'all'}'),
              baseQuery: _query,
              resetKey: _filter,
              pageSize: 20,
              emptyLabel: _filter == null
                  ? 'No support cases yet.'
                  : 'No cases match this filter.',
              itemBuilder: (context, doc) => _CaseRow(doc: doc, currentUid: _currentUid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.doc, required this.currentUid});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final status = (d['status'] as String?) ?? 'open';
    final actor = (d['primaryActor'] as Map?) ?? const {};
    final actorType = (actor['type'] as String?) ?? '';
    final actorId = (actor['id'] as String?) ?? '';
    final assignedTo = d['assignedTo'] as String?;
    final me = currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/support/${doc.id}'),
        leading: _StatusDot(status: status),
        title: Text(
          (d['title'] as String?) ?? '(untitled)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${supportCaseActorLabel(actorType)} $actorId · '
          '${supportCaseCategoryLabel((d['category'] as String?) ?? '')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(supportCaseStatusLabel(status),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              assignedTo == null
                  ? 'Unassigned'
                  : (assignedTo == me ? 'You' : 'Assigned'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'waiting':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 6, backgroundColor: _color);
  }
}

class _CreateCaseDialog extends StatefulWidget {
  const _CreateCaseDialog({required this.firestore});
  final FirebaseFirestore firestore;

  @override
  State<_CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<_CreateCaseDialog> {
  final _titleController = TextEditingController();
  final _actorIdController = TextEditingController();
  String _actorType = kSupportCaseActorTypes.first;
  String _category = kSupportCaseCategories.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _actorIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final actorId = _actorIdController.text.trim();
    if (title.isEmpty || actorId.isEmpty) {
      setState(() => _error = 'Title and the actor\'s id are both required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instance.httpsCallable('createSupportCase').call<Map<String, dynamic>>({
        'title': title,
        'category': _category,
        'primaryActor': {'type': _actorType, 'id': actorId},
      });
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Could not create that case.');
    } catch (e) {
      setState(() => _error = 'Could not create that case.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New support case'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in kSupportCaseCategories)
                    DropdownMenuItem(value: c, child: Text(supportCaseCategoryLabel(c))),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _actorType,
                decoration: const InputDecoration(labelText: 'Who this case is about'),
                items: [
                  for (final t in kSupportCaseActorTypes)
                    DropdownMenuItem(value: t, child: Text(supportCaseActorLabel(t))),
                ],
                onChanged: (v) => setState(() => _actorType = v!),
              ),
              TextField(
                controller: _actorIdController,
                decoration: const InputDecoration(
                  labelText: 'Their id',
                  helperText: 'The id from their profile\'s URL, e.g. /users/abc123',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add more detail as a note once the case is created.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
