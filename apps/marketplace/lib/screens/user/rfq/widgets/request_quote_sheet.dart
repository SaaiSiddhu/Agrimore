import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/rfq_provider.dart';
import '../../../../app/routes.dart';

/// Bottom sheet for requesting a bulk quote on a B2B-enabled product
/// (Phase RFQ-2). Triggered from product_details_screen.dart. Mirrors
/// Phase AI-3's _AiConnectFormSheet pattern: isolated StatefulWidget so its
/// form state doesn't leak into the caller.
class RequestQuoteSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final int moq;
  final bool isDark;

  const RequestQuoteSheet({
    Key? key,
    required this.productId,
    required this.productName,
    required this.moq,
    required this.isDark,
  }) : super(key: key);

  @override
  State<RequestQuoteSheet> createState() => _RequestQuoteSheetState();
}

class _RequestQuoteSheetState extends State<RequestQuoteSheet> {
  late final TextEditingController _quantityController =
      TextEditingController(text: widget.moq > 0 ? widget.moq.toString() : '');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      SnackbarHelper.showWarning(context, 'Enter a valid quantity');
      return;
    }
    final priceText = _priceController.text.trim();
    final proposedPrice = priceText.isEmpty ? null : double.tryParse(priceText);
    if (priceText.isNotEmpty && proposedPrice == null) {
      SnackbarHelper.showWarning(context, 'Enter a valid price, or leave it blank to just ask for a quote');
      return;
    }

    setState(() => _submitting = true);
    final rfqProvider = context.read<RfqProvider>();
    try {
      final rfqId = await rfqProvider.createRfq(
        productId: widget.productId,
        quantity: quantity,
        proposedPrice: proposedPrice,
        notes: _notesController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.showSuccess(context, 'Quote request sent to the seller');
        Navigator.pushNamed(context, AppRoutes.rfqDetail, arguments: rfqId);
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, rfqProvider.error ?? 'Failed to send your quote request');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request a Quote',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            widget.productName,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              helperText: widget.moq > 1 ? 'Minimum order quantity: ${widget.moq}' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Your proposed price per unit (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
