import 'package:flutter/material.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/screens/store_search_results_page.dart';

class StoreSearchBar extends StatefulWidget {
  const StoreSearchBar({super.key});

  @override
  State<StoreSearchBar> createState() => _StoreSearchBarState();
}

class _StoreSearchBarState extends State<StoreSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    // Navigate to search results page
    // Empty query will show all products
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoreSearchResultsPage(searchQuery: query.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const card = Colors.white;
    const border = Color(0xFFE0E0E0);
    const muted = Color(0xFF9AA0A6);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: const TextStyle(color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'Search in Store',
          hintStyle: const TextStyle(color: muted),
          prefixIcon: const Icon(Icons.search, color: muted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: muted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() {});
        },
        onSubmitted: _performSearch,
      ),
    );
  }
}
