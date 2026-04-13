import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const CategoryCard({
    Key? key,
    required this.category,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (category.imageUrl != null)
                Image.network(
                  category.imageUrl!,
                  height: 50,
                  width: 50,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.category),
                )
              else
                const Icon(Icons.category, size: 50),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
