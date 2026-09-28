// lib/screens/admin/delivery/rider_support_screen.dart
//
// Phase DLVSUP1 — rider support tickets (rider_support_tickets), newest
// first. A standalone screen rather than another RiderPayoutsScreen tab,
// mirroring RiderIncidentsScreen's own structure (Open/Closed tabs, an
// action-based single review callable) rather than the identity/vehicle/
// bank change-request tabs' binary approve/reject shape -- a ticket has a
// 3-state lifecycle (submitted/seen/closed), not a 2-state decision.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rider_incidents_admin.dart' show appBarTabs, ageLabel;
import '../widgets/actor_support_cases_section.dart' show createOrOpenCaseFromSource;

/// ADMR-68: maps this collection's own category vocabulary onto the
/// support-case category vocabulary -- a pre-fill, never authoritative;
/// the admin can still change it before the real command runs.
String _mapToSupportCategory(String? ticketCategory) => switch (ticketCategory) {
      'delivery_issue' => 'delivery_issue',
      'earnings_payouts' => 'payment_issue',
      'account_documents' => 'account_issue',
      _ => 'other',
    };

class RiderSupportScreen extends StatelessWidget {
  const RiderSupportScreen({super.key, FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

  /// Injectable so a widget test never needs a real Firebase connection,
  /// mirroring SupportCaseDetailScreen's own established pattern.
  final FirebaseFirestore? _firestoreOverride;

  @override
  Widget build(BuildContext context) {
    final firestore = _firestoreOverride ?? FirebaseFirestore.instance;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Support'),
          bottom: appBarTabs(context, const [Tab(text: 'Open'), Tab(text: 'Closed')]),
        ),
        body: TabBarView(children: [
          _TicketList(open: true, firestore: firestore),
          _TicketList(open: false, firestore: firestore),
        ]),
      ),
    );
  }
}

String _categoryLabel(String? category) => switch (category) {
      'delivery_issue' => 'Delivery issue',
      'earnings_payouts' => 'Earnings & payouts',
      'account_documents' => 'Account & documents',
      _ => 'Unknown',
    };

String _statusLabel(String? status) => switch (status) {
      'submitted' => 'New — not seen',
      'seen' => 'Seen',
      'closed' => 'Closed',
      _ => 'Unknown',
    };

/// Refusals from updateSupportRequest.
String _supportRefusal(String code, String? reason) => switch (reason) {
      'already_closed' => 'Someone already closed this request.',
      'note_required' => 'Write what was done (3–500 characters).',
      'not_found' => 'This request no longer exists.',
      _ => code == 'permission-denied' ? 'Only admins can update support requests.' : 'Could not update the request. Try again.',
    };

class _TicketList extends StatefulWidget {
  const _TicketList({required this.open, required this.firestore});
  final bool open;
  final FirebaseFirestore firestore;
  @override
  State<_TicketList> createState() => _TicketListState();
}

class _TicketListState extends State<_TicketList> {
  // Index: rider_support_tickets status ASC, createdAt DESC.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = (widget.open
          ? widget.firestore.collection('rider_support_tickets').where('status', whereIn: const ['submitted', 'seen'])
          : widget.firestore.collection('rider_support_tickets').where('status', isEqualTo: 'closed'))
      .orderBy('createdAt', descending: true)
      .limit(widget.open ? 200 : 50)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Rider support tickets: ${snap.error}');
          return _message('Could not load requests. Check your connection and reopen this page.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _message(widget.open ? 'No open requests.' : 'No closed requests yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _TicketCard(id: docs[i].id, data: docs[i].data(), firestore: widget.firestore),
        );
      },
    );
  }
}

Widget _message(String text) =>
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

String _who(Object? uid) {
  final u = (uid ?? '').toString();
  if (u.isEmpty) return '';
  if (u == FirebaseAuth.instance.currentUser?.uid) return 'you';
  return 'admin ${u.substring(0, u.length < 6 ? u.length : 6)}';
}

class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.id, required this.data, required this.firestore});
  final String id;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _busy = false;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _rider = _listen();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _listen() =>
      widget.firestore.collection('delivery_partners').doc((widget.data['riderId'] ?? '').toString()).snapshots();

  @override
  void didUpdateWidget(_TicketCard old) {
    super.didUpdateWidget(old);
    if (old.data['riderId'] != widget.data['riderId']) _rider = _listen();
  }

  Future<void> _update(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('updateSupportRequest').call<Map<String, dynamic>>({
        'ticketId': widget.id,
        'action': action,
        if (note != null) 'note': note,
      });
      if (mounted) SnackbarHelper.showSuccess(context, action == 'close' ? 'Request closed' : 'Marked as seen');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('updateSupportRequest: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (mounted) SnackbarHelper.showError(context, _supportRefusal(e.code, reason));
    } catch (e) {
      debugPrint('updateSupportRequest: $e');
      if (mounted) SnackbarHelper.showError(context, _supportRefusal('unknown', null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final text = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Close request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The rider sees this text exactly as written.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(labelText: 'What was done', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = text.text.trim();
                if (t.length < 3 || t.length > 500) {
                  return setD(() => error = 'Write what was done (3–500 characters)');
                }
                Navigator.pop(ctx, t);
              },
              child: const Text('Close request'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (result != null) await _update('close', note: result);
  }

  Future<void> _openAttachment(String path) async {
    try {
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) {
        SnackbarHelper.showError(context, 'Could not open the attachment.');
      }
    } catch (e) {
      debugPrint('Support attachment $path: $e');
      if (mounted) SnackbarHelper.showError(context, 'Could not open the attachment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cs = Theme.of(context).colorScheme;
    final status = d['status'] as String?;
    final created = _date(d['createdAt']);
    final message = (d['message'] as String?)?.trim() ?? '';
    final attachmentPath = d['attachmentPath'] as String?;
    final isNew = status == 'submitted';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isNew ? cs.error : cs.outlineVariant, width: isNew ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent_rounded, color: isNew ? cs.error : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _rider,
                    builder: (context, snap) => Text(
                      (snap.data?.data()?['name'] as String?) ?? 'Rider',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                Chip(
                  label: Text(_statusLabel(status)),
                  backgroundColor: isNew ? cs.errorContainer : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (created != null)
              Text('${AgFormat.dateTime(created)} · ${ageLabel(DateTime.now().difference(created))} ago',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_categoryLabel(d['category'] as String?), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message),
            if (attachmentPath != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _openAttachment(attachmentPath),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('View attachment'),
              ),
            ],
            if (status == 'seen' || status == 'closed')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (d['seenBy'] != null) 'Seen by ${_who(d['seenBy'])}',
                    if (status == 'closed') 'closed by ${_who(d['closedBy'])}',
                  ].join(' · '),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            if (status == 'closed')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Outcome: ${d['resolutionNote'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isNew)
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _update('mark_seen'),
                    child: const Text('Mark seen'),
                  ),
                if (status != 'closed')
                  FilledButton(
                    onPressed: _busy ? null : _close,
                    child: const Text('Close'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => createOrOpenCaseFromSource(
                    context,
                    sourceType: 'rider_ticket',
                    sourceId: widget.id,
                    defaultCategory: _mapToSupportCategory(d['category'] as String?),
                  ),
                  icon: const Icon(Icons.folder_special_outlined, size: 18),
                  label: const Text('Create/open case'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
