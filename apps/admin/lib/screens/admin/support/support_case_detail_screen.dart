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
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../orders/web_download_stub.dart' if (dart.library.html) '../orders/web_download_impl.dart' as web_download;
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
    _tabController = TabController(length: 4, vsync: this);
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

  Future<void> _addLink(Map<String, dynamic> data) async {
    final link = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (link == null) return;
    await _call(
      'linkSupportCaseRecord',
      {'caseId': widget.caseId, 'link': link, 'expectedVersion': data['version']},
      successMessage: 'Link added',
    );
  }

  Future<void> _removeLink(Map<String, dynamic> data, Map<String, dynamic> link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this link?'),
        content: Text(
          'This only removes the relationship from this case. It does not change or delete the '
          '${linkRecordTypeLabel(link['type'] as String? ?? '').toLowerCase()} itself.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _call(
      'unlinkSupportCaseRecord',
      {'caseId': widget.caseId, 'link': link, 'expectedVersion': data['version']},
      successMessage: 'Link removed',
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
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Notes'),
                  Tab(text: 'Activity'),
                  Tab(text: 'Linked Records'),
                  Tab(text: 'Evidence'),
                ],
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
                    _LinkedRecordsTab(
                      firestore: _firestore,
                      data: data,
                      busy: _busy,
                      onAdd: () => _addLink(data),
                      onRemove: (link) => _removeLink(data, link),
                    ),
                    _EvidenceTab(
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

// ADMR-68 — link/unlink UI for linkSupportCaseRecord/unlinkSupportCaseRecord
// (ADMR-65, backend-only until now). For the four types with a real
// People-360/Order-360 detail route, shows a working "View" link; for the
// three per-rider operational types with no dedicated detail screen in
// this codebase, shows an honest inline summary of the linked record's own
// key fields instead of a fabricated route or an unfiltered global list.

class _LinkedRecordsTab extends StatelessWidget {
  const _LinkedRecordsTab({
    required this.firestore,
    required this.data,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });
  final FirebaseFirestore firestore;
  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic> link) onRemove;

  @override
  Widget build(BuildContext context) {
    final links = ((data['linkedRecords'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add_link),
            label: const Text('Add link'),
          ),
        ),
        const SizedBox(height: 8),
        if (links.isEmpty)
          const SectionMessage(icon: Icons.link_off, message: 'No linked records yet.'),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LinkedRecordTile(
              firestore: firestore,
              link: link,
              busy: busy,
              onRemove: () => onRemove(link),
            ),
          ),
      ],
    );
  }
}

class _LinkedRecordTile extends StatelessWidget {
  const _LinkedRecordTile({
    required this.firestore,
    required this.link,
    required this.busy,
    required this.onRemove,
  });
  final FirebaseFirestore firestore;
  final Map<String, dynamic> link;
  final bool busy;
  final VoidCallback onRemove;

  /// A short, honest inline summary for the three types with no dedicated
  /// detail screen -- never a route to a page that doesn't exist.
  String _summarize(String type, Map<String, dynamic> d) {
    switch (type) {
      case 'rider_ticket':
        return '${d['category'] ?? 'ticket'} · ${d['status'] ?? 'unknown'}';
      case 'rider_incident':
        return '${d['kind'] ?? 'incident'} · ${d['status'] ?? 'unknown'}';
      case 'delivery_exception':
        return '${d['reason'] ?? 'exception'} · ${d['status'] ?? 'unknown'}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (link['type'] as String?) ?? '';
    final id = (link['id'] as String?) ?? '';
    final route = linkRecordRoute(type, id);
    final collection = kLinkRecordCollection[type];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text(linkRecordTypeLabel(type)),
        subtitle: collection == null
            ? Text(id)
            : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: firestore.collection(collection).doc(id).get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Text('Loading…');
                  if (!snap.data!.exists) {
                    return const Text('This record no longer exists.');
                  }
                  final d = snap.data!.data()!;
                  if (route.isNotEmpty) return Text(id);
                  return Text(_summarize(type, d));
                },
              ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (route.isNotEmpty)
              TextButton(onPressed: () => context.push(route), child: const Text('View')),
            IconButton(
              tooltip: 'Remove link',
              icon: const Icon(Icons.link_off),
              onPressed: busy ? null : onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  String _type = kLinkRecordTypes.first;
  final _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a linked record'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Record type'),
              items: [
                for (final t in kLinkRecordTypes)
                  DropdownMenuItem(value: t, child: Text(linkRecordTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Its id',
                helperText: 'The id from its own profile/record URL',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final id = _idController.text.trim();
            if (id.isEmpty) return;
            Navigator.pop(context, {'type': _type, 'id': id});
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ADMR-71 — private evidence attachments. Storage path is deterministic
// (support_case_evidence/{caseId}/{requestId}), computed the same way the
// server itself computes it (functions/src/admin/supportCases.ts's own
// evidencePath) -- never a client-invented path. A retry reuses the SAME
// requestId; the object at that path is write-once (storage.rules), so the
// upload step itself is skipped on a genuine retry (see _upload below) and
// only the idempotent finalize call is repeated -- never a duplicate
// evidence record. attachSupportCaseEvidenceCore's own request-id-keyed
// idempotency handles the server side exactly like
// createSupportCase/addSupportCaseNote (ADMR-66).

/// Mirrors functions/src/admin/supportCases.ts's own MAX_EVIDENCE_BYTES.
const int kMaxEvidenceBytes = 10 * 1024 * 1024;

// ADMR-76: same emulator dart-defines main.dart itself reads (ADMR-75) --
// read independently here since these are compile-time constants, not
// runtime state; duplicating the read, not the value, is simpler than
// threading it through every screen. onRequest functions (like
// viewSupportCaseEvidence) are not reachable via FirebaseFunctions.instance,
// which only knows how to invoke Callables -- a real HTTP base URL is
// needed for this one.
const bool _useFirebaseEmulatorForEvidence =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
const String _evidenceEmulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const int _evidenceFunctionsEmulatorPort =
    int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const String kAgrimoreProjectId = 'agrimore-66a4e';
const String kAgrimoreFunctionsRegion = 'us-central1';

/// The real, deployed HTTPS base URL in a normal build; the local emulator's
/// equivalent when `--dart-define=USE_FIREBASE_EMULATOR=true` was passed.
String get evidenceFunctionsBaseUrl => _useFirebaseEmulatorForEvidence
    ? 'http://$_evidenceEmulatorHost:$_evidenceFunctionsEmulatorPort/$kAgrimoreProjectId/$kAgrimoreFunctionsRegion'
    : 'https://$kAgrimoreFunctionsRegion-$kAgrimoreProjectId.cloudfunctions.net';
class _EvidenceTab extends StatefulWidget {
  const _EvidenceTab({required this.firestore, required this.caseId, required this.currentUid});
  final FirebaseFirestore firestore;
  final String caseId;

  /// Storage's own create-only rule checks `fileName.matches(request.auth.uid
  /// + '_.*')` -- the client must embed this SAME uid in the path it uploads
  /// to, or its own upload would be refused by the rule it is meant to satisfy.
  final String? currentUid;

  @override
  State<_EvidenceTab> createState() => _EvidenceTabState();
}

class _EvidenceTabState extends State<_EvidenceTab> {
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  bool _uploading = false;
  double _progress = 0;
  String? _error;
  PlatformFile? _pendingFile;
  String? _pendingRequestId;

  String? _contentTypeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.pdf')) return 'application/pdf';
    return null;
  }

  /// ADMR-72: functions/src/admin/supportCases.ts's own evidencePath(caseId,
  /// adminUid, requestId) -- mirrored here since Dart cannot import it.
  String _evidencePath(String requestId) {
    return 'support_case_evidence/${widget.caseId}/${widget.currentUid}_$requestId';
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) SnackbarHelper.showError(context, 'Could not read that file. Try again.');
      return;
    }
    // A newly picked file is always a DISTINCT logical operation -- a fresh
    // requestId (and so a fresh Storage path) even if the admin picks the
    // exact same file again, matching the write-once rule's own semantics.
    final requestId = const Uuid().v4();
    setState(() {
      _pendingFile = file;
      _pendingRequestId = requestId;
      _error = null;
    });
    await _upload(file, requestId);
  }

  Future<void> _retry() async {
    final file = _pendingFile;
    final requestId = _pendingRequestId;
    if (file == null || requestId == null) return;
    await _upload(file, requestId);
  }

  Future<void> _upload(PlatformFile file, String requestId) async {
    if (widget.currentUid == null) {
      setState(() => _error = 'You must be signed in to attach evidence.');
      return;
    }
    final contentType = _contentTypeFor(file.name);
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      if (contentType == null) {
        throw Exception('Unsupported file type');
      }
      final path = _evidencePath(requestId);
      final ref = FirebaseStorage.instance.ref(path);
      // ADMR-72: the object at this path is write-once (storage.rules:
      // `resource == null`) -- a SECOND putData to the same path is always
      // refused, even by the original uploader. A retry after a lost
      // finalize acknowledgment must not attempt to re-upload; it should go
      // straight to the (idempotent) finalize call instead. Distinguish
      // "never uploaded" from "already uploaded, finalize just didn't land"
      // by checking existence first, rather than blindly retrying putData.
      var alreadyUploaded = false;
      try {
        await ref.getMetadata();
        alreadyUploaded = true;
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
        alreadyUploaded = false;
      }
      if (!alreadyUploaded) {
        final task = ref.putData(file.bytes!, SettableMetadata(contentType: contentType));
        task.snapshotEvents.listen((snapshot) {
          if (mounted && snapshot.totalBytes > 0) {
            setState(() => _progress = snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
        await task;
      }
      await FirebaseFunctions.instance.httpsCallable('attachSupportCaseEvidence').call<Map<String, dynamic>>({
        'caseId': widget.caseId,
        'requestId': requestId,
        'originalFileName': file.name,
      });
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Evidence attached');
        setState(() {
          _pendingFile = null;
          _pendingRequestId = null;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not attach that evidence. You can retry.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Upload failed. You can retry — nothing will be duplicated.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Attach evidence'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Photos or PDF documents, up to 10MB. Only admins can view these.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (_uploading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 6),
                ),
                const SizedBox(height: 4),
                Text('Uploading… ${(_progress * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
              ],
              if (_error != null && !_uploading) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: PaginatedQueryList(
            baseQuery: widget.firestore
                .collection('support_case_evidence')
                .where('caseId', isEqualTo: widget.caseId)
                .orderBy('uploadedAt', descending: true),
            emptyLabel: 'No evidence attached yet.',
            itemBuilder: (context, doc) {
              final d = doc.data();
              return _EvidenceTile(data: d);
            },
          ),
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatefulWidget {
  const _EvidenceTile({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_EvidenceTile> createState() => _EvidenceTileState();
}

class _EvidenceTileState extends State<_EvidenceTile> {
  bool _loading = false;

  bool get _isImage => ((widget.data['contentType'] as String?) ?? '').startsWith('image/');

  // ADMR-76: ADMR-72's own switch to getData() was believed to re-check
  // authorization on every call, closing getDownloadURL()'s persistent-
  // bypass-token gap. CONFIRMED WRONG for Flutter WEB specifically by
  // reading the actual installed firebase_storage_web package source:
  // getData() there still calls getDownloadURL() internally and fetches via
  // a plain, unauthenticated HTTP GET against that same public URL. Fixed
  // with a genuine authenticated backend endpoint instead
  // (viewSupportCaseEvidence) -- a fresh ID token is sent on EVERY view
  // (never cached), verified server-side WITH REVOCATION CHECKED, and the
  // live object's generation is compared against what was recorded at
  // finalize time before any byte is ever streamed back.
  Future<void> _view(BuildContext context) async {
    final evidenceId = widget.data['evidenceId'] as String?;
    final name = (widget.data['originalFileName'] as String?) ?? 'evidence';
    if (evidenceId == null) return;
    // Defense in depth: the server already refuses anything over this size
    // at finalize time, so a recorded size beyond it would mean something
    // is already wrong -- refuse before fetching a potentially huge payload
    // into browser/device memory rather than trusting the record blindly.
    final recordedSize = widget.data['size'] as num?;
    if (recordedSize != null && recordedSize > kMaxEvidenceBytes) {
      SnackbarHelper.showError(context, 'This file is unexpectedly large and was not opened.');
      return;
    }
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) SnackbarHelper.showError(context, 'Sign in again to view this file.');
        return;
      }
      final idToken = await user.getIdToken();
      final uri = Uri.parse('$evidenceFunctionsBaseUrl/viewSupportCaseEvidence')
          .replace(queryParameters: {'evidenceId': evidenceId});
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
      if (response.statusCode == 409) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'This file changed unexpectedly and could not be verified.');
        }
        return;
      }
      if (response.statusCode != 200) {
        if (context.mounted) SnackbarHelper.showError(context, 'This file could not be read.');
        return;
      }
      final bytes = response.bodyBytes;
      if (_isImage) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              content: InteractiveViewer(
                child: Image.memory(bytes, errorBuilder: (_, __, ___) => const Text('Could not load image.')),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            ),
          );
        }
        return;
      }
      // PDF: a real open/download interaction, never a raw URL string.
      if (kIsWeb) {
        web_download.downloadFile(bytes, name);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        if (!context.mounted) return;
        await Share.shareXFiles([XFile(file.path)], text: name);
      }
    } catch (_) {
      if (context.mounted) SnackbarHelper.showError(context, 'Could not open this file.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _sizeLabel(num? bytes) {
    if (bytes == null) return '';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['originalFileName'] as String?) ?? 'Evidence file';
    final uploadedBy = (widget.data['uploadedBy'] as String?) ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(_isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
        title: Text(name),
        subtitle: Text('${_sizeLabel(widget.data['size'] as num?)} · uploaded by $uploadedBy'),
        trailing: Wrap(
          spacing: 4,
          children: [
            _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: () => _view(context), child: const Text('View')),
            _Timestamp(value: widget.data['uploadedAt']),
          ],
        ),
      ),
    );
  }
}
