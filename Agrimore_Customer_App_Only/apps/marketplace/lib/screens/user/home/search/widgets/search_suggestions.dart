import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class SearchSuggestions extends StatelessWidget {
  final String query;
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const SearchSuggestions({
    Key? key,
    required this.query,
    required this.suggestions,
    required this.onSuggestionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppColors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No suggestions found',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: suggestions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.lightGrey,
      ),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final queryLower = query.toLowerCase();
        final suggestionLower = suggestion.toLowerCase();
        final startIndex = suggestionLower.indexOf(queryLower);

        return ListTile(
          onTap: () {
            HapticFeedback.lightImpact();
            onSuggestionTap(suggestion);
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: startIndex >= 0
              ? RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: suggestion.substring(0, startIndex),
                      ),
                      TextSpan(
                        text: suggestion.substring(
                          startIndex,
                          startIndex + query.length,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(
                        text: suggestion.substring(startIndex + query.length),
                      ),
                    ],
                  ),
                )
              : Text(
                  suggestion,
                  style: AppTextStyles.bodyLarge,
                ),
          trailing: Icon(
            Icons.north_west_rounded,
            color: AppColors.grey,
            size: 20,
          ),
        );
      },
    );
  }
}
