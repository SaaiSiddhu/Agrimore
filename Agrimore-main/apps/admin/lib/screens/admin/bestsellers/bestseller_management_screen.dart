// lib/screens/admin/bestsellers/bestseller_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/bestseller_provider.dart';
import '../../../app/themes/admin_colors.dart';
import 'edit_bestseller_slot_dialog.dart';

class BestsellerManagementScreen extends StatefulWidget {
  const BestsellerManagementScreen({Key? key}) : super(key: key);

  @override
  State<BestsellerManagementScreen> createState() => _BestsellerManagementScreenState();
}

class _BestsellerManagementScreenState extends State<BestsellerManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BestsellerProvider>().loadSlots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text(
          'Bestsellers Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BestsellerProvider>().loadSlots(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<BestsellerProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.loadSlots(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: AdminColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bestseller Slots',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure 9 category slots for the home screen Bestsellers section',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3x3 Grid of Slots
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final slot = provider.getSlotByPosition(index + 1) ??
                        BestsellerSlotModel.empty(index + 1);
                    return _SlotCard(
                      slot: slot,
                      onEdit: () => _openEditDialog(slot),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEditDialog(BestsellerSlotModel slot) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditBestsellerSlotDialog(slot: slot),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final BestsellerSlotModel slot;
  final VoidCallback onEdit;

  const _SlotCard({
    required this.slot,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasCategory = slot.categoryId.isNotEmpty;
    final images = slot.images;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: hasCategory ? slot.bgColor.withOpacity(0.5) : AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCategory ? slot.bgColor : AdminColors.border,
            width: hasCategory ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Slot Position Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: hasCategory 
                    ? AdminColors.primary 
                    : Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Text(
                'Slot ${slot.position}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasCategory ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),

            // Content
            Expanded(
              child: hasCategory
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 2x2 Image Preview
                        if (images.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                children: List.generate(4, (i) {
                                  if (i < images.length) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        images[i],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(color: Colors.grey[200]),
                                      ),
                                    );
                                  }
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 36,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        
                        // Category Name
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(11),
                            ),
                          ),
                          child: Text(
                            slot.categoryName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure Slot',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
