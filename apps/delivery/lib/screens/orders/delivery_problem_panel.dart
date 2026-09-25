// lib/screens/orders/delivery_problem_panel.dart
//
// Phase DLV-E1 / Phase 25 — reporting a delivery problem after pickup and
// showing the exception record's real state.
import 'package:agrimore_core/agrimore_core.dart' show DeliveryFailureReason;
import 'package:flutter/material.dart';

import '../../delivery/delivery_problems.dart';
import '../../delivery/rider_steps.dart';
import '../../design_system/design_system.dart';
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
  late final Stream<Map<String, dynamic>?> _order =
      widget.orderStream ?? _safeWatchOrder(widget.orderId);
  String? _watchedId;
  Stream<Map<String, dynamic>?>? _exception;

  static Stream<Map<String, dynamic>?> _safeWatchOrder(String id) {
    try {
      return watchOrder(id);
    } catch (_) {
      return Stream.value(const {});
    }
  }

  static Stream<Map<String, dynamic>?> _safeWatchException(String id) {
    try {
      return watchException(id);
    } catch (_) {
      return Stream.value(null);
    }
  }

  Stream<Map<String, dynamic>?> _exceptionFor(String id) {
    if (id != _watchedId) {
      _watchedId = id;
      _exception = (widget.exceptionStream ?? _safeWatchException)(id);
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
          if (!isAfterPickup((order['orderStatus'] as String?) ?? '')) {
            return const SizedBox.shrink();
          }
          return DeliveryButton.secondary(
            key: const ValueKey('report-problem'),
            label: l.problemReport,
            icon: DeliveryIcons.warning,
            onPressed: _report,
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
    final c = context.colors;
    final t = context.text;
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
        padding: const EdgeInsets.all(DeliverySpace.md),
        decoration: BoxDecoration(
          color: c.warning.container,
          borderRadius: DeliveryRadius.rMd,
          border: Border.all(
            color: c.warning.border,
            width: DeliverySize.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  DeliveryIcons.warning,
                  size: DeliveryIconSize.sm,
                  color: c.warning.icon,
                ),
                const SizedBox(width: DeliverySpace.sm),
                Expanded(
                  child: Text(
                    title,
                    style: t.titleSmall.copyWith(color: c.warning.text),
                  ),
                ),
              ],
            ),
            if (body != null) ...[
              const SizedBox(height: DeliverySpace.xxs),
              Text(
                body,
                style: t.bodyMedium.copyWith(color: c.textPrimary),
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: DeliverySpace.xxs),
              Text(
                l.problemResolutionNote(note),
                style: t.bodyMedium.copyWith(color: c.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProblemReportSheet extends StatefulWidget {
  const ProblemReportSheet({
    super.key,
    required this.orderId,
    required this.backend,
    this.fix,
  });
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

  Future<Map<String, dynamic>> _defaultFix() async =>
      positionPayload(await currentRiderFix());

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    Map<String, dynamic> fix = const {};
    try {
      fix = await (widget.fix ?? _defaultFix)().timeout(
        DeliveryMotion.locationTimeout,
      );
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
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        0,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.page,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.problemSheetTitle,
              style: t.titleMedium.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            RadioGroup<DeliveryFailureReason>(
              groupValue: _reason,
              onChanged: (v) {
                if (!_sending) setState(() => _reason = v);
              },
              child: Column(
                children: [
                  for (final r in afterPickupReasons)
                    RadioListTile<DeliveryFailureReason>(
                      key: ValueKey('reason-${r.wire}'),
                      value: r,
                      enabled: !_sending,
                      title: Text(reasonText(l, r)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.problemNoteLabel),
            ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
                child: Text(
                  problemFailureText(l, _failure!),
                  style: t.bodyMedium.copyWith(color: c.danger.text),
                ),
              ),
            FilledButton(
              key: const ValueKey('problem-send'),
              onPressed: _reason == null || _sending ? null : _send,
              child: Text(l.problemSend),
            ),
          ],
        ),
      ),
    );
  }
}
