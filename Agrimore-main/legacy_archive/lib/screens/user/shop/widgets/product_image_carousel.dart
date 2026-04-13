// lib/screens/user/shop/widgets/product_image_carousel.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // ✅ KEEP THIS
import '../../../../app/themes/app_colors.dart';

class ProductImageCarousel extends StatefulWidget {
  final List<String> images;

  const ProductImageCarousel({
    Key? key,
    required this.images,
  }) : super(key: key);

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController(); // ✅ FIXED TYPE

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 400,
        color: Colors.grey[100],
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 100,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          carouselController: _carouselController, // ✅ NOW CORRECT TYPE
          options: CarouselOptions(
            height: 400,
            viewportFraction: 1.0,
            enableInfiniteScroll: widget.images.length > 1,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: widget.images.map((imageUrl) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.contain,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        if (widget.images.length > 1)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final isSelected = _currentIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      _carouselController.animateToPage(index); // ✅ NOW WORKS
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(widget.images[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.images.asMap().entries.map((entry) {
                return Container(
                  width: _currentIndex == entry.key ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == entry.key
                        ? AppColors.primary
                        : Colors.grey[300],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
