import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/share_service.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../core/widgets/motion_widgets.dart';
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
    {'id': 'vibe_check', 'label': 'Vibe Checks'},
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
    setState(() {});
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
    ref.read(historyRevisionProvider.notifier).state++;
    _loadItems();
  }

  Future<void> _toggleFavorite(HistoryItem item) async {
    final db = ref.read(localDatabaseProvider);
    await db.toggleFavorite(item.id, !item.isFavorite);
    ref.read(historyRevisionProvider.notifier).state++;
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
      ref.read(historyRevisionProvider.notifier).state++;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      selectedColor: isDark ? AppColors.accent : AppColors.primary,
                      backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
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
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      children: const [
                        ResultCardSkeleton(),
                        ResultCardSkeleton(),
                        ResultCardSkeleton(),
                        ResultCardSkeleton(),
                      ],
                    )
                  : _items.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
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
                                        : item.type == 'vibe_check'
                                            ? Icons.local_fire_department_rounded
                                            : Icons.brush_outlined;

                            final typeColor = item.type == 'reply'
                                ? (isDark ? AppColors.accentWarm : AppColors.primary)
                                : item.type == 'caption'
                                    ? AppColors.accent
                                    : item.type == 'bio'
                                        ? AppColors.sageGreen
                                        : item.type == 'vibe_check'
                                            ? AppColors.emberOrange
                                            : AppColors.accentPink;

                            final dateLabel = _dateGroupLabel(item.createdAt);
                            final showDateHeader = index == 0 ||
                                _dateGroupLabel(_items[index - 1].createdAt) != dateLabel;
                            final thumbBytes = _decodeCardPreview(item);

                            return StaggeredEntrance(
                              key: ValueKey<String>('hist_${item.id}'),
                              index: index,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDateHeader)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          bottom: 8, top: index == 0 ? 0 : 6),
                                      child: Text(
                                        dateLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.accentWarm
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(typeIcon,
                                                      size: 14, color: typeColor),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      item.category.toUpperCase(),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: typeColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '• $formattedDate',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TactileScale(
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    icon: Icon(
                                                      item.isFavorite
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border_rounded,
                                                      color: item.isFavorite
                                                          ? AppColors.accentPink
                                                          : (isDark ? Colors.white38 : AppColors.textSecondaryLight),
                                                      size: 18,
                                                    ),
                                                    tooltip: 'Favorite',
                                                    onPressed: () {
                                                      HapticFeedback.selectionClick();
                                                      _toggleFavorite(item);
                                                    },
                                                  ),
                                                ),
                                                TactileScale(
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    icon: Icon(Icons.copy_rounded,
                                                        size: 18,
                                                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
                                                    tooltip: 'Copy',
                                                    onPressed: () =>
                                                        ShareService.copyToClipboard(
                                                            context, item.content),
                                                  ),
                                                ),
                                                TactileScale(
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    icon: Icon(
                                                        Icons.share_rounded,
                                                        size: 18,
                                                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
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
                                                ),
                                                TactileScale(
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    icon: const Icon(
                                                        Icons.delete_outline_rounded,
                                                        size: 18,
                                                        color: AppColors.error),
                                                    tooltip: 'Delete',
                                                    onPressed: () =>
                                                        _deleteItem(item.id),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (thumbBytes != null) ...[
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.memory(
                                                  thumbBytes,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const SizedBox.shrink(),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                            ],
                                            Expanded(
                                              child: Text(
                                                item.content,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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

  String _dateGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(itemDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, y').format(dt);
  }

  Uint8List? _decodeCardPreview(HistoryItem item) {
    final raw = item.extraData;
    if (item.type != 'card' || raw == null) return null;
    const prefix = 'data:image/png;base64,';
    if (!raw.startsWith(prefix)) return null;
    try {
      return base64Decode(raw.substring(prefix.length));
    } catch (_) {
      return null;
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.accent : AppColors.primary).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded,
                  size: 40, color: isDark ? AppColors.accentWarm : AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No creations found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your generated replies, captions, and created cards will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
