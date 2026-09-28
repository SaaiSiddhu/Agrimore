import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_problems_admin.dart';
import 'rider_incidents_admin.dart' show ageLabel, incidentMapsUrl, appBarTabs;
import '../widgets/actor_support_cases_section.dart' show createOrOpenCaseFromSource;

/// Phase DLV-E1: problems riders reported after pickup (delivery_exceptions),
/// newest first. Acknowledge, then resolve as "rider will try again" or
/// "goods returned to the seller" through updateDeliveryException. Neither
/// changes the order's money — refunds, cancellation and rider pay for a
/// failed attempt are done in the order tools (open owner policy).
class DeliveryProblemsScreen extends StatelessWidget {
  const DeliveryProblemsScreen({super.key, FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

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
          title: const Text('Delivery Problems'),
          bottom: appBarTabs(context, const [Tab(text: 'Open'), Tab(text: 'Resolved')]),
        ),
        body: TabBarView(children: [
          _ProblemList(open: true, firestore: firestore),
          _ProblemList(open: false, firestore: firestore),
        ]),
      ),
    );
  }
}

class _ProblemList extends StatefulWidget {
  const _ProblemList({required this.open, required this.firestore});
  final bool open;
  final FirebaseFirestore firestore;
  @override
  State<_ProblemList> createState() => _ProblemListState();
}

class _ProblemListState extends State<_ProblemList> {
  // Index: delivery_exceptions status ASC, createdAt DESC.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = (widget.open
          ? widget.firestore.collection('delivery_exceptions').where('status', whereIn: openProblemStatuses)
          : widget.firestore.collection('delivery_exceptions').where('status', isEqualTo: 'resolved'))
      .orderBy('createdAt', descending: true)
      .limit(widget.open ? 200 : 50)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Delivery problems: ${snap.error}');
          return _message('Could not load problems. Check your connection and reopen this page.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _message(widget.open ? 'No open delivery problems.' : 'No resolved problems yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ProblemCard(id: docs[i].id, data: docs[i].data(), firestore: widget.firestore),
        );
      },
    );
  }
}

Widget _message(String text) =>
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));

String _who(Object? uid) {
  final u = (uid ?? '').toString();
  if (u.isEmpty) return '';
  if (u == FirebaseAuth.instance.currentUser?.uid) return 'you';
  return 'admin ${u.substring(0, u.length < 6 ? u.length : 6)}';
}

class _ProblemCard extends StatefulWidget {
  const _ProblemCard({required this.id, required this.data, required this.firestore});
  final String id;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  @override
  State<_ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<_ProblemCard> {
  bool _busy = false;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _rider =
      widget.firestore.collection('delivery_partners').doc((widget.data['riderId'] ?? '').toString()).snapshots();

  Future<void> _update(String action, {String? disposition, String? resolution}) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('updateDeliveryException').call<Map<String, dynamic>>({
        'exceptionId': widget.id,
        'action': action,
        if (disposition != null) 'disposition': disposition,
        if (resolution != null) 'resolution': resolution,
      });
      if (mounted) SnackbarHelper.showSuccess(context, action == 'resolve' ? 'Problem resolved' : 'Acknowledged');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('updateDeliveryException: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (mounted) SnackbarHelper.showError(context, problemRefusal(e.code, reason));
    } catch (e) {
      debugPrint('updateDeliveryException: $e');
      if (mounted) SnackbarHelper.showError(context, problemRefusal('unknown', null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final text = TextEditingController();
    String disposition = problemDispositions.first.$1;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Resolve problem'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (value, label) in problemDispositions)
              RadioListTile<String>(
                value: value,
                groupValue: disposition,
                onChanged: (v) => setD(() => disposition = v ?? disposition),
                title: Text(label),
                contentPadding: EdgeInsets.zero,
              ),
            const Text('This records what happened. Refunds, cancelling the order and the rider\'s pay for '
                'this attempt are done in the order tools.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: text,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(labelText: 'What was decided (the rider sees this)', errorText: error),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final e = problemResolutionError(text.text);
                if (e != null) return setD(() => error = e);
                Navigator.pop(ctx, true);
              },
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );
    final resolution = text.text.trim();
    text.dispose();
    if (ok == true) await _update('resolve', disposition: disposition, resolution: resolution);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cs = Theme.of(context).colorScheme;
    final status = d['status'] as String?;
    final created = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
    final loc = d['location'] is Map ? Map<String, dynamic>.from(d['location'] as Map) : null;
    final maps = incidentMapsUrl(loc);
    final note = (d['note'] as String?)?.trim() ?? '';
    final isNew = status == 'reported';
    final cod = (d['paymentMethod'] as String?)?.toLowerCase() == 'cod';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isNew ? cs.error : cs.outlineVariant, width: isNew ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Order ${d['orderNumber'] ?? d['orderId'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Chip(label: Text(problemStatusLabel(status)), backgroundColor: isNew ? cs.errorContainer : null),
          ]),
          Text(problemReasonLabel(d['reason'] as String?), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (created != null)
            Text('${AgFormat.dateTime(created)} · ${ageLabel(DateTime.now().difference(created))} ago',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${custodyLabel(d['custody'] as String?)}${cod ? ' · cash on delivery' : ''}'),
          if (note.isNotEmpty) Text('Rider wrote: $note', style: const TextStyle(fontStyle: FontStyle.italic)),
          if (status == 'resolved') ...[
            const SizedBox(height: 4),
            Text('Resolution: ${d['resolution'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Resolved by ${_who(d['resolvedBy'])}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _rider,
              builder: (context, snap) {
                final phone = ((snap.data?.data()?['phone'] as String?) ?? '').replaceAll(RegExp(r'[\s-]'), '');
                if (phone.isEmpty) return const SizedBox.shrink();
                return OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text('Call rider ${AgFormat.maskPhone(phone)}'),
                );
              },
            ),
            if (maps != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(maps), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Open map'),
              ),
            if (isNew)
              FilledButton.tonal(onPressed: _busy ? null : () => _update('acknowledge'), child: const Text('Acknowledge')),
            if (status != 'resolved') FilledButton(onPressed: _busy ? null : _resolve, child: const Text('Resolve')),
            OutlinedButton.icon(
              onPressed: () => createOrOpenCaseFromSource(
                context,
                sourceType: 'delivery_exception',
                sourceId: widget.id,
                defaultCategory: 'delivery_issue',
              ),
              icon: const Icon(Icons.folder_special_outlined, size: 18),
              label: const Text('Create/open case'),
            ),
          ]),
        ]),
      ),
    );
  }
}
