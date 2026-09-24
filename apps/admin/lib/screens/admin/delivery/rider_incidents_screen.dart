import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rider_incidents_admin.dart';

/// Phase DLV-S2: riders' safety reports (rider_incidents), newest first.
/// Only the server writes them; this screen acknowledges and resolves
/// through updateRiderIncident. There is no push to admins yet — the team
/// sees a report when this screen is open, so "New" is shown loudly.
class RiderIncidentsScreen extends StatelessWidget {
  const RiderIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Incidents'),
          bottom: const TabBar(tabs: [Tab(text: 'Open'), Tab(text: 'Resolved')]),
        ),
        body: const TabBarView(children: [_IncidentList(open: true), _IncidentList(open: false)]),
      ),
    );
  }
}

final FirebaseFirestore _db = FirebaseFirestore.instance;

class _IncidentList extends StatefulWidget {
  const _IncidentList({required this.open});
  final bool open;
  @override
  State<_IncidentList> createState() => _IncidentListState();
}

class _IncidentListState extends State<_IncidentList> {
  // Created once (a stream built in build() resubscribes on every rebuild).
  // Index: rider_incidents status ASC, createdAt DESC.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = (widget.open
          ? _db.collection('rider_incidents').where('status', whereIn: openIncidentStatuses)
          : _db.collection('rider_incidents').where('status', isEqualTo: 'resolved'))
      .orderBy('createdAt', descending: true)
      .limit(widget.open ? 200 : 50)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Rider incidents: ${snap.error}');
          return _message('Could not load incidents. Check your connection and reopen this page.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _message(widget.open ? 'No open incidents.' : 'No resolved incidents yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _IncidentCard(id: docs[i].id, data: docs[i].data()),
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

class _IncidentCard extends StatefulWidget {
  const _IncidentCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
  @override
  State<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<_IncidentCard> {
  bool _busy = false;
  // The rider's phone number, read live so the team can call back.
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _rider = _listen();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _listen() =>
      _db.collection('delivery_partners').doc((widget.data['riderId'] ?? '').toString()).snapshots();

  @override
  void didUpdateWidget(_IncidentCard old) {
    super.didUpdateWidget(old);
    if (old.data['riderId'] != widget.data['riderId']) _rider = _listen();
  }

  Future<void> _update(String action, {String? resolution}) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('updateRiderIncident').call<Map<String, dynamic>>({
        'incidentId': widget.id,
        'action': action,
        if (resolution != null) 'resolution': resolution,
      });
      if (mounted) SnackbarHelper.showSuccess(context, action == 'resolve' ? 'Incident resolved' : 'Acknowledged');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('updateRiderIncident: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (mounted) SnackbarHelper.showError(context, incidentRefusal(e.code, reason));
    } catch (e) {
      debugPrint('updateRiderIncident: $e');
      if (mounted) SnackbarHelper.showError(context, incidentRefusal('unknown', null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final text = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Resolve incident'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The rider sees this text exactly as written.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'What was done',
                  hintText: 'e.g. Called the rider; safe, bike towed to the store',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final e = resolutionError(text.text);
                if (e != null) return setD(() => error = e);
                Navigator.pop(ctx, text.text.trim());
              },
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (result != null) await _update('resolve', resolution: result);
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        SnackbarHelper.showError(context, 'Could not open ${uri.scheme == 'tel' ? 'the phone app' : 'the map'}.');
      }
    } catch (e) {
      debugPrint('Launch $uri: $e');
      if (mounted) SnackbarHelper.showError(context, 'Could not open that link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cs = Theme.of(context).colorScheme;
    final status = d['status'] as String?;
    final created = _date(d['createdAt']);
    final loc = d['location'] is Map ? Map<String, dynamic>.from(d['location'] as Map) : null;
    final maps = incidentMapsUrl(loc);
    final note = (d['note'] as String?)?.trim() ?? '';
    final riderStatus = d['riderStatus'] as String?;
    final isNew = status == 'reported';

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
                Icon(Icons.sos_rounded, color: isNew ? cs.error : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((d['riderName'] as String?) ?? 'Rider',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Chip(
                  label: Text(incidentStatusLabel(status)),
                  backgroundColor: isNew ? cs.errorContainer : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (created != null)
              Text('${AgFormat.dateTime(created)} · ${ageLabel(DateTime.now().difference(created))} ago',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            if (riderStatus != null && riderStatus != 'approved')
              Text('Rider account: $riderStatus', style: TextStyle(color: cs.error, fontSize: 12)),
            const SizedBox(height: 8),
            Text(incidentOrdersLine(d['activeOrderIds'])),
            const SizedBox(height: 4),
            Text(created == null ? 'Position recorded' : incidentLocationLine(loc, created),
                style: TextStyle(color: loc?['isMocked'] == true ? cs.error : null)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Rider wrote: $note', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (status == 'acknowledged' || status == 'resolved')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (d['acknowledgedBy'] != null) 'Acknowledged by ${_who(d['acknowledgedBy'])}',
                    if (status == 'resolved') 'resolved by ${_who(d['resolvedBy'])}',
                  ].join(' · '),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            if (status == 'resolved')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child:
                    Text('Resolution: ${d['resolution'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _rider,
                  builder: (context, snap) {
                    final phone = ((snap.data?.data()?['phone'] as String?) ?? '').replaceAll(RegExp(r'[\s-]'), '');
                    if (phone.isEmpty) return const SizedBox.shrink();
                    return OutlinedButton.icon(
                      onPressed: () => _open(Uri(scheme: 'tel', path: phone)),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text('Call rider ${AgFormat.maskPhone(phone)}'),
                    );
                  },
                ),
                if (maps != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri.parse(maps)),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Open map'),
                  ),
                  IconButton(
                    tooltip: 'Copy coordinates',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => Clipboard.setData(ClipboardData(text: '${loc!['lat']},${loc['lng']}')),
                  ),
                ],
                if (isNew)
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _update('acknowledge'),
                    child: const Text('Acknowledge'),
                  ),
                if (status != 'resolved')
                  FilledButton(
                    onPressed: _busy ? null : _resolve,
                    child: const Text('Resolve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
