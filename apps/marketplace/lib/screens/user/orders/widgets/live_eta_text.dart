// The order card/details ETA uses the same server route and shared calculator
// as live tracking. Subscriptions belong to one opening owner and order.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/delivery_tracking_service.dart';

class LiveEtaText extends StatefulWidget {
  const LiveEtaText({
    super.key,
    required this.orderId,
    required this.ownerId,
    required this.orderStatus,
    required this.isDark,
    this.titleSize = 15,
    this.taskSnapshots,
    this.liveSnapshots,
    this.now,
  });

  final String orderId;
  final String ownerId;
  final String orderStatus;
  final bool isDark;
  final double titleSize;
  final Stream<DeliveryTaskModel?> Function(String)? taskSnapshots;
  final Stream<RiderLivePoint?> Function(String)? liveSnapshots;
  final DateTime Function()? now;

  @override
  State<LiveEtaText> createState() => _LiveEtaTextState();
}

class _LiveEtaTextState extends State<LiveEtaText> {
  late final AuthProvider _openingAuth;
  late final String _owner;
  late final String _orderId;
  late final int _version;
  late final Stream<DeliveryTaskModel?> Function(String)? _taskTransport;
  late final Stream<RiderLivePoint?> Function(String)? _liveTransport;
  late final DeliveryTrackingService _service = DeliveryTrackingService();
  StreamSubscription<DeliveryTaskModel?>? _taskSubscription;
  StreamSubscription<RiderLivePoint?>? _liveSubscription;
  Timer? _clock;
  DeliveryTaskModel? _task;
  RiderLivePoint? _live;
  bool _expired = false;
  bool _taskFailed = false;
  int _liveEpoch = 0;

  bool get _owns =>
      mounted &&
      !_expired &&
      _owner.isNotEmpty &&
      _orderId.isNotEmpty &&
      !_orderId.contains('/') &&
      identical(context.read<AuthProvider>(), _openingAuth) &&
      _openingAuth.isSessionCurrent(_owner, _version) &&
      widget.ownerId == _owner &&
      widget.orderId == _orderId &&
      widget.taskSnapshots == _taskTransport &&
      widget.liveSnapshots == _liveTransport;

  @override
  void initState() {
    super.initState();
    _openingAuth = context.read<AuthProvider>();
    _owner = widget.ownerId;
    _orderId = widget.orderId;
    _version = _openingAuth.sessionVersion;
    _taskTransport = widget.taskSnapshots;
    _liveTransport = widget.liveSnapshots;
    _openingAuth.addListener(_onAuthChanged);
    if (!_owns) {
      _expire();
      return;
    }
    _taskSubscription =
        (_taskTransport ?? _service.streamTask)(_orderId).listen((task) {
      if (!_owns) return;
      if (task != null &&
          (task.orderId != _orderId ||
              (task.customerId != null && task.customerId != _owner))) {
        setState(_expire);
        return;
      }
      setState(() {
        _task = task;
        _taskFailed = false;
      });
      if (task == null) {
        _cancelLive();
      } else {
        _listenLive();
      }
    }, onError: (Object error) {
      if (!_owns) return;
      setState(() {
        _task = null;
        _taskFailed = true;
        _cancelLive();
      });
    });
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_owns && _task != null) setState(() {});
    });
  }

  void _listenLive() {
    if (!_owns || _task == null || _liveSubscription != null) return;
    final epoch = ++_liveEpoch;
    _liveSubscription =
        (_liveTransport ?? _service.streamLivePoint)(_orderId).listen((live) {
      if (_owns && epoch == _liveEpoch && _task != null) {
        setState(() => _live = live);
      }
    }, onError: (Object error) {
      if (_owns && epoch == _liveEpoch) setState(() => _live = null);
    });
  }

  void _cancelLive() {
    _liveEpoch++;
    _liveSubscription?.cancel();
    _liveSubscription = null;
    _live = null;
  }

  void _expire() {
    _expired = true;
    _taskSubscription?.cancel();
    _taskSubscription = null;
    _cancelLive();
    _clock?.cancel();
    _task = null;
  }

  void _onAuthChanged() {
    if (mounted && !_owns) setState(_expire);
  }

  @override
  void didUpdateWidget(covariant LiveEtaText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_owns) _expire();
  }

  @override
  void dispose() {
    _openingAuth.removeListener(_onAuthChanged);
    _expire();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    if (!_owns) {
      _expire();
      return const SizedBox.shrink();
    }
    final task = _task;
    final eta = _taskFailed
        ? null
        : DeliveryEtaCalculator.estimate(
            status: task?.status,
            rider: _live,
            pickup: task?.pickup,
            drop: task?.drop,
            route: task?.route,
            now: widget.now?.call() ?? DateTime.now(),
          );
    final stage =
        DeliveryTrackingService.stageMessage(task?.status, widget.orderStatus);
    final title = _taskFailed
        ? 'Tracking is unavailable right now.'
        : eta == null
            ? stage
            : DeliveryEtaCalculator.label(eta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: widget.titleSize,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : Colors.black87)),
        if (eta != null) ...[
          const SizedBox(height: 3),
          Text(stage,
              style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ],
    );
  }
}
