import 'package:flutter/material.dart';
import '../../../../models/product_model.dart';
import 'product_card.dart';

class ProductList extends StatelessWidget {
  final List<ProductModel> products;

  const ProductList({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProductCard(product: products[index]),
        );
      },
    );
  }
}
