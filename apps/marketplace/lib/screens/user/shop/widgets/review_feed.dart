import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/review_provider.dart';

/// A product-scoped public feed. Unavailability is distinct from confirmed empty.
class ReviewFeed extends StatefulWidget {
  const ReviewFeed({super.key, required this.productId, required this.builder});
  final String productId;
  final Widget Function(BuildContext, List<ReviewModel>) builder;
  @override
  State<ReviewFeed> createState() => _ReviewFeedState();
}

class _ReviewFeedState extends State<ReviewFeed> {
  ReviewProvider? _provider;
  String? _product;
  int? _filter;
  int _generation = 0;
  Stream<List<ReviewModel>>? _stream;
  bool _unavailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(covariant ReviewFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  void _bind() {
    final provider = context.watch<ReviewProvider>();
    if (identical(provider, _provider) &&
        _product == widget.productId &&
        _filter == provider.filterRating) {
      return;
    }
    _provider = provider;
    _product = widget.productId;
    _filter = provider.filterRating;
    _connect();
  }

  void _connect() {
    _generation++;
    _stream = null;
    _unavailable = false;
    final product = _product!;
    if (product.isEmpty || product.trim() != product || product.contains('/')) {
      _unavailable = true;
      return;
    }
    try {
      _stream = _provider!.getReviewsStream(product);
    } catch (_) {
      _unavailable = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider!;
    final product = _product!;
    final filter = _filter;
    final generation = _generation;
    Widget unavailable() => SingleChildScrollView(
            child: ErrorView(
          message: 'Reviews are unavailable right now.',
          useThemeColors: true,
          onRetry: () {
            if (!mounted ||
                widget.productId != product ||
                _generation != generation ||
                !identical(context.read<ReviewProvider>(), provider) ||
                provider.filterRating != filter) {
              return;
            }
            setState(_connect);
          },
        ));
    if (_unavailable) return unavailable();
    return StreamBuilder<List<ReviewModel>>(
      key: ValueKey(generation),
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return unavailable();
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.done) {
            return unavailable();
          }
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()));
        }
        final reviews = snapshot.data!;
        if (reviews.any((review) => review.productId != product)) {
          return unavailable();
        }
        return widget.builder(context, reviews);
      },
    );
  }
}
