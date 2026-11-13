import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/share_service.dart';
import '../../models/history_item.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, reply, caption, card, favorites
  List<HistoryItem> _items = [];
  bool _isLoading = true;

  final List<Map<String, String>> _filterTabs = [
    {'id': 'all', 'label': 'All'},
    {'id': 'favorites', 'label': 'Favorites'},
    {'id': 'reply', 'label': 'Replies'},
    {'id': 'caption', 'label': 'Captions'},
    {'id': 'bio', 'label': 'Bios'},
    {'id': 'card', 'label': 'Cards'},
  ];

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadItems();
    });
  }

  int _searchRequestId = 0;

  Future<void> _loadItems() async {
    final currentRequestId = ++_searchRequestId;
    setState(() => _isLoading = true);
    final db = ref.read(localDatabaseProvider);

    final isFavoritesOnly = _selectedFilter == 'favorites';
    final typeFilter =
        (isFavoritesOnly || _selectedFilter == 'all') ? null : _selectedFilter;

    final query = _searchController.text.trim();
    final results = await db.getItems(
      type: typeFilter,
      onlyFavorites: isFavoritesOnly,
      query: query.isEmpty ? null : query,
    );

    if (mounted && currentRequestId == _searchRequestId) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    final db = ref.read(localDatabaseProvider);
    await db.deleteItem(id);
    _loadItems();
  }

  Future<void> _toggleFavorite(HistoryItem item) async {
    final db = ref.read(localDatabaseProvider);
    await db.toggleFavorite(item.id, !item.isFavorite);
    _loadItems();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all your saved creations and history on this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(localDatabaseProvider);
      await db.clearAll();
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local history cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Favorites'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All History',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search your creations...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadItems();
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: _filterTabs.map((tab) {
                  final isSelected = _selectedFilter == tab['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tab['label']!),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedFilter = tab['id']!);
                        _loadItems();
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimaryDark,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final formattedDate = DateFormat('MMM d, h:mm a')
                                .format(item.createdAt);

                            final typeIcon = item.type == 'reply'
                                ? Icons.chat_bubble_outline_rounded
                                : item.type == 'caption'
                                    ? Icons.auto_awesome_rounded
                                    : item.type == 'bio'
                                        ? Icons.badge_outlined
                                        : Icons.brush_outlined;

                            final typeColor = item.type == 'reply'
                                ? AppColors.primary
                                : item.type == 'caption'
                                    ? AppColors.accent
                                    : item.type == 'bio'
                                        ? Colors.cyan
                                        : AppColors.accentPink;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCardDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderDark),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(typeIcon,
                                              size: 14, color: typeColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.category.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: typeColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• $formattedDate',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMutedDark),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              item.isFavorite
                                                  ? Icons.favorite
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: item.isFavorite
                                                  ? AppColors.accentPink
                                                  : null,
                                              size: 18,
                                            ),
                                            tooltip: 'Favorite',
                                            onPressed: () =>
                                                _toggleFavorite(item),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded,
                                                size: 18),
                                            tooltip: 'Copy',
                                            onPressed: () =>
                                                ShareService.copyToClipboard(
                                                    context, item.content),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.share_rounded,
                                                size: 18),
                                            tooltip: 'Share',
                                            onPressed: () {
                                              if (item.type == 'card' &&
                                                  item.extraData != null) {
                                                ShareService.shareImage(
                                                    item.extraData!,
                                                    text: item.content);
                                              } else {
                                                ShareService.shareText(
                                                    item.content);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AppColors.error),
                                            tooltip: 'Delete',
                                            onPressed: () =>
                                                _deleteItem(item.id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.content,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded,
                  size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text(
              'No creations found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your generated replies, captions, and created cards will appear here.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
    );
  }
}
