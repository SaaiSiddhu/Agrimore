// ADMR-62 — Support case detail.
//
// Wires the six real ADMR-61 callables (create is on the queue screen;
// assign/change-status/add-note/resolve/reopen live here) to a live view
// of one support_cases document. No client-side write ever touches
// support_cases/support_case_notes/support_case_events directly -- every
// mutation is a callable, matching their `allow write: if false` rules.
//
// Optimistic concurrency: every mutating action reads `version` from the
// CURRENT StreamBuilder snapshot at the moment the button is pressed, not
// a value cached at an earlier build -- so two admins racing on the same
// case behave exactly as ADMR-61's own emulator tests proved server-side
// (first wins, second gets a clear "changed since you last viewed it"
// message), never a silent overwrite.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../widgets/paginated_query_list.dart';
import 'support_case_constants.dart';

class SupportCaseDetailScreen extends StatefulWidget {
  const SupportCaseDetailScreen({
    super.key,
    required this.caseId,
    FirebaseFirestore? firestore,
    String? currentUid,
  })  : _firestoreOverride = firestore,
        _currentUidOverride = currentUid;

  final String caseId;
  final FirebaseFirestore? _firestoreOverride;

  /// Injectable so a widget test never needs a real signed-in
  /// FirebaseAuth user, mirroring [_firestoreOverride].
  final String? _currentUidOverride;

  @override
  State<SupportCaseDetailScreen> createState() => _SupportCaseDetailScreenState();
}

class _SupportCaseDetailScreenState extends State<SupportCaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore =
      widget._firestoreOverride ?? FirebaseFirestore.instance;
  late final String? _currentUid =
      widget._currentUidOverride ?? FirebaseAuth.instance.currentUser?.uid;
  late final TabController _tabController;
  int _activityRefreshTick = 0;
  bool _busy = false;
  final _noteRequestIds = SupportRequestIdTracker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _call(
    String name,
    Map<String, dynamic> data, {
    String? successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call<Map<String, dynamic>>(data);
      if (mounted && successMessage != null) {
        SnackbarHelper.showSuccess(context, successMessage);
      }
      if (mounted) setState(() => _activityRefreshTick++);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.message ?? 'Could not complete that. Please try again.');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Could not complete that. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> data) async {
    final uid = await showDialog<String>(
      context: context,
      builder: (_) => _PickAdminDialog(firestore: _firestore),
    );
    if (uid == null) return;
    await _call(
      'assignSupportCase',
      {'caseId': widget.caseId, 'assigneeUid': uid, 'expectedVersion': data['version']},
      successMessage: 'Case assigned',
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> data) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ChangeStatusDialog(),
    );
    if (result == null) return;
    await _call(
      'changeSupportCaseStatus',
      {
        'caseId': widget.caseId,
        'status': result['status'],
        if (result['waitingReason'] != null) 'waitingReason': result['waitingReason'],
        'expectedVersion': data['version'],
      },
      successMessage: 'Status updated',
    );
  }

  Future<void> _resolve(Map<String, dynamic> data) async {
    final summary = await _promptForText(
      title: 'Resolve case',
      label: 'Resolution summary',
      confirmLabel: 'Resolve',
    );
    if (summary == null) return;
    await _call(
      'resolveSupportCase',
      {'caseId': widget.caseId, 'resolutionSummary': summary, 'expectedVersion': data['version']},
      successMessage: 'Case resolved',
    );
  }

  Future<void> _reopen(Map<String, dynamic> data) async {
    final reason = await _promptForText(
      title: 'Reopen case',
      label: 'Reason for reopening',
      confirmLabel: 'Reopen',
    );
    if (reason == null) return;
    await _call(
      'reopenSupportCase',
      {'caseId': widget.caseId, 'reason': reason, 'expectedVersion': data['version']},
      successMessage: 'Case reopened',
    );
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.length < 3) return;
              Navigator.pop(ctx, v);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _addNote() async {
    final text = await _promptForText(title: 'Add note', label: 'Note', confirmLabel: 'Add');
    if (text == null) return;
    final requestId = _noteRequestIds.forPayload(text);
    await _call('addSupportCaseNote', {'caseId': widget.caseId, 'text': text, 'requestId': requestId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Support Case'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('support-case-${widget.caseId}'),
        stream: _firestore.collection('support_cases').doc(widget.caseId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const SectionMessage(
              icon: Icons.error_outline,
              message: "Couldn't load this case. Check your connection and try again.",
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SectionMessage(
              icon: Icons.search_off,
              message: 'This support case no longer exists.',
            );
          }
          final data = snap.data!.data()!;
          final status = (data['status'] as String?) ?? 'open';

          return Column(
            children: [
              _CaseHeader(
                data: data,
                busy: _busy,
                currentUid: _currentUid,
                onAssign: () => _assign(data),
                onChangeStatus: status == 'resolved' ? null : () => _changeStatus(data),
                onResolve: status == 'resolved' ? null : () => _resolve(data),
                onReopen: status == 'resolved' ? () => _reopen(data) : null,
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                tabs: const [Tab(text: 'Notes'), Tab(text: 'Activity')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _NotesTab(
                      firestore: _firestore,
                      caseId: widget.caseId,
                      currentUid: _currentUid,
                      onAddNote: _addNote,
                    ),
                    _ActivityTab(
                      key: ValueKey('activity-$_activityRefreshTick'),
                      firestore: _firestore,
                      caseId: widget.caseId,
                      currentUid: _currentUid,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({
    required this.data,
    required this.busy,
    required this.currentUid,
    required this.onAssign,
    required this.onChangeStatus,
    required this.onResolve,
    required this.onReopen,
  });
  final Map<String, dynamic> data;
  final bool busy;
  final String? currentUid;
  final VoidCallback onAssign;
  final VoidCallback? onChangeStatus;
  final VoidCallback? onResolve;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final actor = (data['primaryActor'] as Map?) ?? const {};
    final actorType = (actor['type'] as String?) ?? '';
    final actorId = (actor['id'] as String?) ?? '';
    final actorRoute = supportCaseActorRoute(actorType, actorId);
    final status = (data['status'] as String?) ?? 'open';
    final assignedTo = data['assignedTo'] as String?;
    final me = currentUid;
    final waitingReason = data['waitingReason'] as String?;
    final resolutionSummary = data['resolutionSummary'] as String?;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (data['title'] as String?) ?? '(untitled)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text(supportCaseStatusLabel(status))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              supportCaseCategoryLabel((data['category'] as String?) ?? ''),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('About: ', style: TextStyle(color: Colors.grey.shade600)),
                Text('${supportCaseActorLabel(actorType)} $actorId'),
                if (actorRoute.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.push(actorRoute),
                    child: const Text('View profile'),
                  ),
                ],
              ],
            ),
            Text(
              assignedTo == null
                  ? 'Unassigned'
                  : 'Assigned to ${assignedTo == me ? 'you' : assignedTo}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (status == 'waiting' && waitingReason != null) ...[
              const SizedBox(height: 4),
              Text('Waiting: $waitingReason'),
            ],
            if (status == 'resolved' && resolutionSummary != null) ...[
              const SizedBox(height: 4),
              Text('Resolution: $resolutionSummary'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onAssign,
                  child: const Text('Assign'),
                ),
                if (onChangeStatus != null)
                  OutlinedButton(
                    onPressed: busy ? null : onChangeStatus,
                    child: const Text('Change status'),
                  ),
                if (onResolve != null)
                  FilledButton(
                    onPressed: busy ? null : onResolve,
                    child: const Text('Resolve'),
                  ),
                if (onReopen != null)
                  FilledButton(
                    onPressed: busy ? null : onReopen,
                    child: const Text('Reopen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({
    required this.firestore,
    required this.caseId,
    required this.currentUid,
    required this.onAddNote,
  });
  final FirebaseFirestore firestore;
  final String caseId;
  final String? currentUid;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddNote,
              icon: const Icon(Icons.add),
              label: const Text('Add note'),
            ),
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            baseQuery: firestore
                .collection('support_case_notes')
                .where('caseId', isEqualTo: caseId)
                .orderBy('createdAt', descending: true),
            emptyLabel: 'No notes yet.',
            itemBuilder: (context, doc) {
              final d = doc.data();
              final author = d['authorUid'] as String?;
              final me = currentUid;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text((d['text'] as String?) ?? ''),
                  subtitle: Text(author == me ? 'You' : (author ?? '')),
                  trailing: _Timestamp(value: d['createdAt']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    super.key,
    required this.firestore,
    required this.caseId,
    required this.currentUid,
  });
  final FirebaseFirestore firestore;
  final String caseId;
  final String? currentUid;

  String _describe(Map<String, dynamic> d) {
    final details = (d['details'] as Map?) ?? const {};
    switch (d['type']) {
      case 'created':
        return 'Case created: ${details['title'] ?? ''}';
      case 'assigned':
        return 'Assigned to ${details['assignee'] ?? ''}';
      case 'status_changed':
        return 'Status changed to ${supportCaseStatusLabel((details['status'] as String?) ?? '')}';
      case 'note_added':
        return 'Note added';
      case 'resolved':
        return 'Resolved: ${details['resolutionSummary'] ?? ''}';
      case 'reopened':
        return 'Reopened: ${details['reason'] ?? ''}';
      default:
        return (d['type'] as String?) ?? 'Event';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedQueryList(
      baseQuery: firestore
          .collection('support_case_events')
          .where('caseId', isEqualTo: caseId)
          .orderBy('at', descending: true),
      emptyLabel: 'No activity yet.',
      itemBuilder: (context, doc) {
        final d = doc.data();
        final actor = d['actorUid'] as String?;
        final me = currentUid;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.circle, size: 8),
          title: Text(_describe(d)),
          subtitle: Text(actor == me ? 'You' : (actor ?? '')),
          trailing: _Timestamp(value: d['at']),
        );
      },
    );
  }
}

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.value});
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    if (value is! Timestamp) return const SizedBox.shrink();
    final dt = (value as Timestamp).toDate();
    final s = '${dt.day}/${dt.month}/${dt.year}';
    return Text(s, style: TextStyle(color: Colors.grey.shade500, fontSize: 11));
  }
}

class _PickAdminDialog extends StatefulWidget {
  const _PickAdminDialog({required this.firestore});
  final FirebaseFirestore firestore;

  @override
  State<_PickAdminDialog> createState() => _PickAdminDialogState();
}

class _PickAdminDialogState extends State<_PickAdminDialog> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _admins;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _admins = widget.firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(200)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign to'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Search'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _admins,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const SectionMessage(
                      icon: Icons.error_outline,
                      message: "Couldn't load admins. Check your connection and try again.",
                    );
                  }
                  var docs = snap.data!.docs;
                  if (_query.isNotEmpty) {
                    docs = docs.where((d) {
                      final name = ((d.data()['name'] as String?) ?? '').toLowerCase();
                      final email = ((d.data()['email'] as String?) ?? '').toLowerCase();
                      return name.contains(_query) || email.contains(_query);
                    }).toList();
                  }
                  if (docs.isEmpty) {
                    return const SectionMessage(icon: Icons.search_off, message: 'No admins match.');
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data();
                      return ListTile(
                        title: Text((data['name'] as String?) ?? d.id),
                        subtitle: Text((data['email'] as String?) ?? ''),
                        onTap: () => Navigator.pop(context, d.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

class _ChangeStatusDialog extends StatefulWidget {
  const _ChangeStatusDialog();

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  String _status = kSupportCaseChangeableStatuses.first;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final s in kSupportCaseChangeableStatuses)
                DropdownMenuItem(value: s, child: Text(supportCaseStatusLabel(s))),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ),
          if (_status == 'waiting') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Waiting reason'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (_status == 'waiting' && reason.length < 3) return;
            Navigator.pop(context, {
              'status': _status,
              if (_status == 'waiting') 'waitingReason': reason,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
