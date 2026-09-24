// lib/screens/orders/delivery_problem_panel.dart
//
// Phase DLV-E1 — on the active order, after pickup: "Report a problem", and
// once reported, the record's real state (reported / seen / resolved as
// reattempt or returned to seller) with Agrimore's words verbatim.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../delivery/delivery_problems.dart';
import '../../delivery/rider_steps.dart' show currentRiderFix, positionPayload;
import '../../l10n/app_localizations.dart';

String reasonText(AppLocalizations l, DeliveryFailureReason r) => switch (r) {
      DeliveryFailureReason.customerUnreachable => l.reasonCustomerUnreachable,
      DeliveryFailureReason.customerRefused => l.reasonCustomerRefused,
      DeliveryFailureReason.wrongAddress => l.reasonWrongAddress,
      DeliveryFailureReason.addressNotFound => l.reasonAddressNotFound,
      DeliveryFailureReason.paymentIssue => l.reasonPaymentIssue,
      DeliveryFailureReason.damagedGoods => l.reasonDamagedGoods,
      DeliveryFailureReason.vehicleIssue => l.reasonVehicleIssue,
      DeliveryFailureReason.safety => l.reasonSafety,
      _ => l.reasonOther,
    };

String problemFailureText(AppLocalizations l, ProblemFailure f) => switch (f) {
      ProblemFailure.notAfterPickup => l.problemFailNotAfterPickup,
      ProblemFailure.alreadyOpen => l.problemFailOpen,
      ProblemFailure.network => l.problemFailNetwork,
      ProblemFailure.unknown => l.problemFailUnknown,
    };

class DeliveryProblemPanel extends StatefulWidget {
  const DeliveryProblemPanel({
    super.key,
    required this.orderId,
    this.backend,
    this.orderStream,
    this.exceptionStream,
    this.fix,
  });

  final String orderId;
  final DeliveryProblemBackend? backend;

  /// Injected in tests.
  final Stream<Map<String, dynamic>?>? orderStream;
  final Stream<Map<String, dynamic>?> Function(String id)? exceptionStream;
  final Future<Map<String, dynamic>> Function()? fix;

  @override
  State<DeliveryProblemPanel> createState() => _DeliveryProblemPanelState();
}

class _DeliveryProblemPanelState extends State<DeliveryProblemPanel> {
  late final Stream<Map<String, dynamic>?> _order = widget.orderStream ?? watchOrder(widget.orderId);
  String? _watchedId;
  Stream<Map<String, dynamic>?>? _exception;

  Stream<Map<String, dynamic>?> _exceptionFor(String id) {
    if (id != _watchedId) {
      _watchedId = id;
      _exception = (widget.exceptionStream ?? watchException)(id);
    }
    return _exception!;
  }

  Future<void> _report() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProblemReportSheet(
        orderId: widget.orderId,
        backend: widget.backend ?? FirebaseDeliveryProblemBackend(),
        fix: widget.fix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _order,
      builder: (context, snap) {
        final order = snap.data;
        if (order == null) return const SizedBox.shrink();
        final openId = openExceptionIdOf(order);
        if (openId == null) {
          if (!isAfterPickup((order['orderStatus'] as String?) ?? '')) return const SizedBox.shrink();
          return OutlinedButton.icon(
            key: const ValueKey('report-problem'),
            onPressed: _report,
            icon: const Icon(AgIcons.warning),
            label: Text(l.problemReport),
          );
        }
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _exceptionFor(openId),
          builder: (context, ex) => _ProblemState(data: ex.data),
        );
      },
    );
  }
}

class _ProblemState extends StatelessWidget {
  const _ProblemState({required this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final state = problemStateOf(data);
    final (title, body) = switch (state) {
      ProblemState.reported => (l.problemReported, l.problemReportedBody),
      ProblemState.seen => (l.problemSeen, l.problemSeenBody),
      ProblemState.reattempt => (l.problemReattempt, null),
      ProblemState.returnedToSeller => (l.problemReturned, null),
    };
    final note = (data?['resolution'] as String?)?.trim();
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('problem-state'),
        width: double.infinity,
        padding: const EdgeInsets.all(WsSpace.s12),
        decoration: BoxDecoration(color: t.warningBg, borderRadius: BorderRadius.circular(WsRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: text.titleSmall?.copyWith(color: t.warningFg)),
          if (body != null) ...[
            const SizedBox(height: WsSpace.s4),
            Text(body, style: text.bodyMedium?.copyWith(color: t.textPrimary)),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: WsSpace.s4),
            Text(l.problemResolutionNote(note), style: text.bodyMedium?.copyWith(color: t.textPrimary)),
          ],
        ]),
      ),
    );
  }
}

class ProblemReportSheet extends StatefulWidget {
  const ProblemReportSheet({super.key, required this.orderId, required this.backend, this.fix});
  final String orderId;
  final DeliveryProblemBackend backend;
  final Future<Map<String, dynamic>> Function()? fix;

  @override
  State<ProblemReportSheet> createState() => _ProblemReportSheetState();
}

class _ProblemReportSheetState extends State<ProblemReportSheet> {
  // One request id per sheet, reused on retry: a lost reply is not a second report.
  final String _requestId = newProblemRequestId();
  final TextEditingController _note = TextEditingController();
  DeliveryFailureReason? _reason;
  ProblemFailure? _failure;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _defaultFix() async => positionPayload(await currentRiderFix());

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    Map<String, dynamic> fix = const {};
    try {
      fix = await (widget.fix ?? _defaultFix)().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await widget.backend.report({
        'orderId': widget.orderId,
        'requestId': _requestId,
        'reason': reason.wire,
        'note': _note.text,
        ...fix,
      });
      if (mounted) Navigator.of(context).pop();
    } on ProblemException catch (e) {
      if (mounted) setState(() => _failure = e.failure);
    } catch (e) {
      debugPrint('Problem report failed: $e');
      if (mounted) setState(() => _failure = ProblemFailure.unknown);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    return Padding(
      padding: EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, MediaQuery.of(context).viewInsets.bottom + WsSpace.page),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.problemSheetTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: WsSpace.s8),
          for (final r in afterPickupReasons)
            RadioListTile<DeliveryFailureReason>(
              key: ValueKey('reason-${r.wire}'),
              value: r,
              groupValue: _reason,
              onChanged: _sending ? null : (v) => setState(() => _reason = v),
              title: Text(reasonText(l, r)),
              contentPadding: EdgeInsets.zero,
            ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(labelText: l.problemNoteLabel),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: WsSpace.s8),
              child: Text(problemFailureText(l, _failure!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.errorFg)),
            ),
          FilledButton(
            key: const ValueKey('problem-send'),
            onPressed: _reason == null || _sending ? null : _send,
            child: Text(l.problemSend),
          ),
        ]),
      ),
    );
  }
}
