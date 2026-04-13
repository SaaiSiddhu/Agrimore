import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final int crossAxisCount;

  const ProductGrid({
    Key? key,
    required this.products,
    this.crossAxisCount = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index]);
      },
    );
  }
}
