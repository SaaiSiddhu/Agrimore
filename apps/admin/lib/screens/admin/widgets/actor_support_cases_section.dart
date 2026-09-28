// ADMR-63 — real support cases for one People-360 actor.
//
// The one shared widget wired into all four People-360 Support tabs
// (Customer/Seller/Delivery Partner/Sales Associate): a real, paginated
// list of support_cases scoped to this exact actor (never leaking a
// sibling actor's cases, matching the server's own constrained
// ActorRef -- proven server-side by ADMR-61's own emulator suite, so
// this widget only needs to prove it queries the right two fields, not
// re-prove authorization), plus a "Raise a case" action that calls
// createSupportCase directly with the actor already fixed -- no re-
// entry of an id the screen already has, unlike the queue screen's own
// generic create dialog.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../support/support_case_constants.dart';
import 'paginated_query_list.dart';

class ActorSupportCasesSection extends StatefulWidget {
  const ActorSupportCasesSection({
    super.key,
    required this.firestore,
    required this.actorType,
    required this.actorId,
    this.title = 'Support cases',
  });

  final FirebaseFirestore firestore;

  /// One of kSupportCaseActorTypes.
  final String actorType;
  final String actorId;

  /// ADMR-64: overridable so Order 360 can stack one of these per actor
  /// role present on an order (e.g. "Seller", "Delivery Partner") without
  /// four identical, undifferentiated "Support cases" headers. Every
  /// existing People-360 caller leaves this at its default -- there,
  /// which actor the section is about is already unambiguous from the
  /// whole screen.
  final String title;

  @override
  State<ActorSupportCasesSection> createState() => _ActorSupportCasesSectionState();
}

class _ActorSupportCasesSectionState extends State<ActorSupportCasesSection> {
  int _refreshTick = 0;

  Future<void> _raiseCase() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _RaiseCaseDialog(actorType: widget.actorType, actorId: widget.actorId),
    );
    if (created == true && mounted) {
      SnackbarHelper.showSuccess(context, 'Case created');
      setState(() => _refreshTick++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title,
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            ),
            OutlinedButton.icon(
              onPressed: _raiseCase,
              icon: const Icon(Icons.add),
              label: const Text('Raise a case'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PaginatedQueryList(
          key: ValueKey('actor-cases-${widget.actorId}-$_refreshTick'),
          baseQuery: widget.firestore
              .collection('support_cases')
              .where('primaryActor.type', isEqualTo: widget.actorType)
              .where('primaryActor.id', isEqualTo: widget.actorId)
              .orderBy('updatedAt', descending: true),
          emptyLabel:
              'No support cases for this ${supportCaseActorLabel(widget.actorType).toLowerCase()} yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) => _CaseTile(doc: doc),
        ),
      ],
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final status = (d['status'] as String?) ?? 'open';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: () => context.push('/support/${doc.id}'),
        title: Text(
          (d['title'] as String?) ?? '(untitled)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(supportCaseCategoryLabel((d['category'] as String?) ?? '')),
        trailing: Chip(
          label: Text(supportCaseStatusLabel(status), style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ADMR-67 — cases genuinely ABOUT one order, not just history for its
// actors. Queries linkedRecords (array-contains {type:'order', id}) rather
// than primaryActor -- a customer's case about a DIFFERENT order must
// never appear here, proven server-side (phaseADMR67_order_specific_cases_
// test.js, o05). Deliberately a separate widget from ActorSupportCasesSection
// rather than a mode flag on it: the query shape, empty-state copy and
// raise-case flow (actor is SELECTABLE here, fixed there) are all different
// enough that a shared widget would need more branching than it saves.
class OrderLinkedSupportCasesSection extends StatefulWidget {
  const OrderLinkedSupportCasesSection({
    super.key,
    required this.firestore,
    required this.orderId,
    required this.availableActors,
  });

  final FirebaseFirestore firestore;
  final String orderId;

  /// Every actor role this specific order actually carries (customer
  /// always; seller/rider/associate only when present) -- mirrors
  /// _buildOrderSupportCasesCard's own conditional list exactly, so
  /// "raise a case" only ever offers an actor genuinely on this order.
  final List<({String type, String id, String label})> availableActors;

  @override
  State<OrderLinkedSupportCasesSection> createState() => _OrderLinkedSupportCasesSectionState();
}

class _OrderLinkedSupportCasesSectionState extends State<OrderLinkedSupportCasesSection> {
  int _refreshTick = 0;

  Future<void> _raiseCase() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _RaiseOrderCaseDialog(orderId: widget.orderId, availableActors: widget.availableActors),
    );
    if (created == true && mounted) {
      SnackbarHelper.showSuccess(context, 'Case created');
      setState(() => _refreshTick++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Cases about this order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            OutlinedButton.icon(
              onPressed: _raiseCase,
              icon: const Icon(Icons.add),
              label: const Text('Raise a case'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PaginatedQueryList(
          key: ValueKey('order-cases-${widget.orderId}-$_refreshTick'),
          baseQuery: widget.firestore
              .collection('support_cases')
              .where('linkedRecords', arrayContains: {'type': 'order', 'id': widget.orderId})
              .orderBy('updatedAt', descending: true),
          emptyLabel: 'No support cases are linked to this order yet.',
          pageSize: 10,
          shrinkWrapInList: true,
          itemBuilder: (context, doc) => _CaseTile(doc: doc),
        ),
      ],
    );
  }
}

class _RaiseOrderCaseDialog extends StatefulWidget {
  const _RaiseOrderCaseDialog({required this.orderId, required this.availableActors});
  final String orderId;
  final List<({String type, String id, String label})> availableActors;

  @override
  State<_RaiseOrderCaseDialog> createState() => _RaiseOrderCaseDialogState();
}

class _RaiseOrderCaseDialogState extends State<_RaiseOrderCaseDialog> {
  final _titleController = TextEditingController();
  String _category = kSupportCaseCategories.first;
  late String _actorType = widget.availableActors.first.type;
  late String _actorId = widget.availableActors.first.id;
  bool _busy = false;
  String? _error;
  final _requestIds = SupportRequestIdTracker();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final requestId =
        _requestIds.forPayload((title, _category, _actorType, _actorId, widget.orderId));
    try {
      await FirebaseFunctions.instance.httpsCallable('createSupportCase').call<Map<String, dynamic>>({
        'title': title,
        'category': _category,
        'primaryActor': {'type': _actorType, 'id': _actorId},
        'initialLink': {'type': 'order', 'id': widget.orderId},
        'requestId': requestId,
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
      title: const Text('Raise a case for this order'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
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
            if (widget.availableActors.length > 1)
              DropdownButtonFormField<String>(
                value: '$_actorType:$_actorId',
                decoration: const InputDecoration(labelText: 'Who this case is primarily about'),
                items: [
                  for (final a in widget.availableActors)
                    DropdownMenuItem(value: '${a.type}:${a.id}', child: Text(a.label)),
                ],
                onChanged: (v) {
                  final actor = widget.availableActors.firstWhere((a) => '${a.type}:${a.id}' == v);
                  setState(() {
                    _actorType = actor.type;
                    _actorId = actor.id;
                  });
                },
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
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

class _RaiseCaseDialog extends StatefulWidget {
  const _RaiseCaseDialog({required this.actorType, required this.actorId});
  final String actorType;
  final String actorId;

  @override
  State<_RaiseCaseDialog> createState() => _RaiseCaseDialogState();
}

class _RaiseCaseDialogState extends State<_RaiseCaseDialog> {
  final _titleController = TextEditingController();
  String _category = kSupportCaseCategories.first;
  bool _busy = false;
  String? _error;
  final _requestIds = SupportRequestIdTracker();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final requestId = _requestIds.forPayload((title, _category, widget.actorType, widget.actorId));
    try {
      await FirebaseFunctions.instance.httpsCallable('createSupportCase').call<Map<String, dynamic>>({
        'title': title,
        'category': _category,
        'primaryActor': {'type': widget.actorType, 'id': widget.actorId},
        'requestId': requestId,
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
      title: Text('Raise a case for this ${supportCaseActorLabel(widget.actorType).toLowerCase()}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
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

// ADMR-68 — a "Create/open a case from this" action shared by the three
// rider-scoped operational screens (rider_support_screen.dart,
// rider_incidents_screen.dart, delivery_problems_screen.dart). Calls the
// real createSupportCaseFromSource directly -- no client-side requestId
// needed here, unlike createSupportCase/addSupportCaseNote: this command's
// own idempotency is keyed by sourceType+sourceId deterministically, proven
// server-side (phaseADMR65_support_case_links_test.js, f02/f08). Prefers
// "opened" language over "created" when alreadyExisted comes back true --
// never the same wording for both, so an admin can tell a fresh case from
// one that already existed for this exact ticket/incident/exception.
Future<void> createOrOpenCaseFromSource(
  BuildContext context, {
  required String sourceType,
  required String sourceId,
  required String defaultCategory,
}) async {
  final result = await showDialog<({String title, String category})>(
    context: context,
    builder: (_) => _CreateFromSourceDialog(defaultCategory: defaultCategory),
  );
  if (result == null || !context.mounted) return;
  try {
    final res = await FirebaseFunctions.instance
        .httpsCallable('createSupportCaseFromSource')
        .call<Map<String, dynamic>>({
      'sourceType': sourceType,
      'sourceId': sourceId,
      'title': result.title,
      'category': result.category,
    });
    final data = res.data as Map;
    final caseId = data['caseId'] as String;
    final alreadyExisted = data['alreadyExisted'] == true;
    if (context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        alreadyExisted ? 'A case already exists for this — opening it' : 'Case created',
      );
      context.push('/support/$caseId');
    }
  } on FirebaseFunctionsException catch (e) {
    if (context.mounted) {
      SnackbarHelper.showError(context, e.message ?? 'Could not create or open that case.');
    }
  } catch (e) {
    if (context.mounted) SnackbarHelper.showError(context, 'Could not create or open that case.');
  }
}

class _CreateFromSourceDialog extends StatefulWidget {
  const _CreateFromSourceDialog({required this.defaultCategory});
  final String defaultCategory;

  @override
  State<_CreateFromSourceDialog> createState() => _CreateFromSourceDialogState();
}

class _CreateFromSourceDialogState extends State<_CreateFromSourceDialog> {
  final _titleController = TextEditingController();
  late String _category = widget.defaultCategory;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create or open a support case for this'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
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
            const SizedBox(height: 4),
            Text(
              'If a case already exists for this exact record, it opens instead of creating a new one.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              setState(() => _error = 'Title is required.');
              return;
            }
            Navigator.pop(context, (title: title, category: _category));
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
