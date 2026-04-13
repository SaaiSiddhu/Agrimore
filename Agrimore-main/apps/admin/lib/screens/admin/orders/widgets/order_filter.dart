import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class OrderFilterWidget extends StatefulWidget {
  final Function(String, String) onFilterChanged;

  const OrderFilterWidget({Key? key, required this.onFilterChanged})
      : super(key: key);

  @override
  State<OrderFilterWidget> createState() => _OrderFilterWidgetState();
}

class _OrderFilterWidgetState extends State<OrderFilterWidget> {
  String _selectedStatus = 'all';
  String _selectedPayment = 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              'Status',
              _selectedStatus,
              ['all', 'pending', 'processing', 'shipped', 'delivered'],
              (value) {
                setState(() => _selectedStatus = value);
                widget.onFilterChanged(_selectedStatus, _selectedPayment);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              'Payment',
              _selectedPayment,
              ['all', 'paid', 'pending', 'failed'],
              (value) {
                setState(() => _selectedPayment = value);
                widget.onFilterChanged(_selectedStatus, _selectedPayment);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: value,
          onChanged: (String? newValue) => onChanged(newValue ?? 'all'),
          isExpanded: true,
          underline: Container(
            height: 1,
            color: Colors.grey[300],
          ),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option.toUpperCase()),
            );
          }).toList(),
        ),
      ],
    );
  }
}
