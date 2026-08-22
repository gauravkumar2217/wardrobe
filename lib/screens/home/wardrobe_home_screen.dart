import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cloth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/style_post.dart';
import '../../services/cloth_service.dart';
import '../../services/style_post_service.dart';
import '../../models/planned_event.dart';
import '../../models/saved_outfit.dart';
import '../../services/planned_event_service.dart';
import '../events/events_planner_screen.dart';
import '../../services/saved_outfit_service.dart';
import '../../services/outfit_suggestion_service.dart';
import '../cloth/cloth_detail_screen.dart';
import '../cloth/add_cloth_flow_screen.dart';
import '../community/trending_styles_screen.dart';
import '../outfit/outfit_generator_screen.dart';
import '../wardrobe/create_wardrobe_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../utils/outfit_planner_days.dart';
import '../../utils/outfit_slots.dart';
import '../../widgets/premium/glass_panel.dart';
import '../../widgets/premium/premium_card.dart';
import '../../widgets/premium/section_header.dart';
import '../../widgets/premium/staggered_fade_in.dart';

class WardrobeHomeScreen extends StatefulWidget {
  const WardrobeHomeScreen({super.key});

  @override
  State<WardrobeHomeScreen> createState() => _WardrobeHomeScreenState();
}

class _WardrobeHomeScreenState extends State<WardrobeHomeScreen> {
  final PageController _outfitController = PageController(viewportFraction: 0.92);
  int _outfitIndex = 0;
  List<_DailyOutfit> _outfits = const [];
  bool _suggestionsLoading = false;
  bool _suggestionsLoaded = false;
  bool _analyticsLoading = false;
  List<_RankedCloth> _mostUsedItems = const [];
  List<_RankedCloth> _leastUsedItems = const [];
  bool _plannerLoading = false;
  List<({String dayKey, String dayLabel, SavedOutfit? outfit})> _weekPlan =
      SavedOutfit.weekPlan(const []);
  bool _eventsLoading = false;
  List<PlannedEvent> _upcomingEvents = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClosetSummary());
  }

  Future<void> _loadClosetSummary({bool forceNewSuggestions = false}) async {
    final auth = context.read<AuthProvider>();
    final wardrobeProvider = context.read<WardrobeProvider>();
    final userId = auth.user?.uid;
    if (userId == null) return;

    try {
      // Fast path: API already includes total_items — skip per-wardrobe count calls
      // that were leaving the home spinner stuck when the API was slow/flaky.
      await wardrobeProvider
          .loadWardrobes(userId, refreshCounts: false)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Home closet summary failed: $e');
    }

    if (!mounted) return;
    await _loadOutfitPlanner();
    await _loadUpcomingEvents();
    if (_hasClothes(context.read<WardrobeProvider>())) {
      await _loadDailyOutfitSuggestions(forceNew: forceNewSuggestions);
    } else if (mounted) {
      setState(() {
        _outfits = const [];
        _suggestionsLoaded = true;
        _suggestionsLoading = false;
        _weekPlan = SavedOutfit.weekPlan(const []);
      });
    }
  }

  Future<void> _loadOutfitPlanner() async {
    setState(() => _plannerLoading = true);
    try {
      final saved = await SavedOutfitService.getSavedOutfits();
      if (!mounted) return;
      setState(() {
        _weekPlan = SavedOutfit.weekPlan(saved);
        _plannerLoading = false;
      });
    } catch (e) {
      debugPrint('Home outfit planner failed: $e');
      if (!mounted) return;
      setState(() => _plannerLoading = false);
    }
  }

  Future<void> _openEventsPlanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EventsPlannerScreen()),
    );
    if (mounted) await _loadUpcomingEvents();
  }

  Future<void> _loadUpcomingEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final events = await PlannedEventService.getEvents(perPage: 5);
      if (!mounted) return;
      setState(() {
        _upcomingEvents = events;
        _eventsLoading = false;
      });
    } catch (e) {
      debugPrint('Home events load failed: $e');
      if (!mounted) return;
      setState(() => _eventsLoading = false);
    }
  }

  Future<void> _openOutfitGenerator() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OutfitGeneratorScreen()),
    );
    if (mounted) await _loadOutfitPlanner();
  }

  Future<void> _loadDailyOutfitSuggestions({bool forceNew = false}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId == null) return;

    setState(() {
      _suggestionsLoading = true;
    });

    try {
      final clothes = await ClothService.getAllUserClothes(userId);
      var suggestions =
          await OutfitSuggestionService.getOrCreateDailySuggestions(
        userId: userId,
        availableClothes: clothes,
        maxSuggestions: 3,
        forceNew: forceNew,
      );

      final byId = <String, Cloth>{for (final c in clothes) c.id: c};

      // If cached sets reference deleted/missing items, rebuild for today.
      final cacheStale = !forceNew &&
          suggestions.isNotEmpty &&
          suggestions.every((s) {
            final resolved = s.clothIds
                .map((id) => byId[id])
                .whereType<Cloth>()
                .length;
            return resolved < 2;
          });
      if (cacheStale) {
        suggestions =
            await OutfitSuggestionService.getOrCreateDailySuggestions(
          userId: userId,
          availableClothes: clothes,
          maxSuggestions: 3,
          forceNew: true,
        );
      }

      final outfits = <_DailyOutfit>[];

      for (var i = 0; i < suggestions.length; i++) {
        final s = suggestions[i];
        final items = s.clothIds
            .map((id) => byId[id])
            .whereType<Cloth>()
            .toList();
        if (items.length < 2) continue;

        final meta = s.metadata;
        final occasion = (meta['occasion'] as String?)?.trim();
        final match = meta['matchPercent'];
        final matchPercent = match is int
            ? match
            : (match is num ? match.round() : 88);

        outfits.add(
          _DailyOutfit(
            title: (s.title?.trim().isNotEmpty == true)
                ? s.title!.trim()
                : 'Look ${i + 1}',
            matchPercent: matchPercent.clamp(1, 99),
            occasion: (occasion != null && occasion.isNotEmpty)
                ? occasion
                : (items.first.occasions.isNotEmpty
                    ? items.first.occasions.first
                    : 'Everyday'),
            note: (s.description?.trim().isNotEmpty == true)
                ? s.description!.trim()
                : 'Styled from your uploaded clothes for today',
            items: items,
            setLabel: 'Set ${i + 1} of ${suggestions.length}',
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _outfits = outfits;
        _outfitIndex = 0;
        _suggestionsLoading = false;
        _suggestionsLoaded = true;
      });
      if (_outfitController.hasClients) {
        _outfitController.jumpToPage(0);
      }
      await _loadClosetAnalytics(userId, clothes);
    } catch (e) {
      debugPrint('Home daily outfit suggestions failed: $e');
      if (!mounted) return;
      setState(() {
        _outfits = const [];
        _suggestionsLoading = false;
        _suggestionsLoaded = true;
      });
      try {
        final clothes = await ClothService.getAllUserClothes(userId);
        await _loadClosetAnalytics(userId, clothes);
      } catch (_) {}
    }
  }

  Future<void> _loadClosetAnalytics(String userId, List<Cloth> clothes) async {
    if (clothes.isEmpty) {
      if (!mounted) return;
      setState(() {
        _mostUsedItems = const [];
        _leastUsedItems = const [];
        _analyticsLoading = false;
      });
      return;
    }

    setState(() => _analyticsLoading = true);

    try {
      const batchSize = 8;
      final ranked = <_RankedCloth>[];

      for (var i = 0; i < clothes.length; i += batchSize) {
        final batch = clothes.skip(i).take(batchSize);
        final batchResults = await Future.wait(
          batch.map((cloth) async {
            final history = await ClothService.getWearHistory(
              userId: userId,
              wardrobeId: cloth.wardrobeId,
              clothId: cloth.id,
            );
            return _RankedCloth(
              cloth: cloth,
              wearCount: history.length,
              lastWorn: history.isNotEmpty ? history.first.wornAt : cloth.wornAt,
            );
          }),
        );
        ranked.addAll(batchResults);
      }

      final most = List<_RankedCloth>.from(ranked)
        ..sort((a, b) {
          final byCount = b.wearCount.compareTo(a.wearCount);
          if (byCount != 0) return byCount;
          final aDate = a.lastWorn;
          final bDate = b.lastWorn;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      final least = List<_RankedCloth>.from(ranked)
        ..sort((a, b) {
          final byCount = a.wearCount.compareTo(b.wearCount);
          if (byCount != 0) return byCount;
          final aDate = a.lastWorn;
          final bDate = b.lastWorn;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return -1;
          if (bDate == null) return 1;
          return aDate.compareTo(bDate);
        });

      if (!mounted) return;
      setState(() {
        _mostUsedItems = most.take(4).toList();
        _leastUsedItems = least.take(4).toList();
        _analyticsLoading = false;
      });
    } catch (e) {
      debugPrint('Home closet analytics failed: $e');
      if (!mounted) return;
      setState(() => _analyticsLoading = false);
    }
  }

  int _totalClothCount(WardrobeProvider wardrobeProvider) {
    return wardrobeProvider.wardrobes.fold<int>(
      0,
      (sum, w) => sum + w.totalItems,
    );
  }

  bool _hasClothes(WardrobeProvider wardrobeProvider) {
    return _totalClothCount(wardrobeProvider) > 0;
  }

  Future<void> _openGetStartedFlow() async {
    final wardrobeProvider = context.read<WardrobeProvider>();

    if (wardrobeProvider.wardrobes.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CreateWardrobeScreen()),
      );
      if (!mounted) return;
      await _loadClosetSummary();
      if (!mounted) return;

      final updated = context.read<WardrobeProvider>();
      if (updated.wardrobes.isEmpty) return;

      final wardrobeId = updated.wardrobes.first.id;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddClothFlowScreen(wardrobeId: wardrobeId),
        ),
      );
      if (mounted) await _loadClosetSummary(forceNewSuggestions: true);
      return;
    }

    if (_totalClothCount(wardrobeProvider) == 0) {
      final wardrobeId = wardrobeProvider.wardrobes.first.id;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddClothFlowScreen(wardrobeId: wardrobeId),
        ),
      );
      if (mounted) await _loadClosetSummary(forceNewSuggestions: true);
      return;
    }

    context.read<NavigationProvider>().navigateToWardrobes();
  }

  @override
  void dispose() {
    _outfitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeProvider = context.watch<WardrobeProvider>();
    final hasClothes = _hasClothes(wardrobeProvider);
    final totalItems = _totalClothCount(wardrobeProvider);
    final wardrobeCount = wardrobeProvider.wardrobes.length;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
            // Daily outfit suggestion — empty state when no clothes
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 0,
                  child: !hasClothes
                      ? _DailyOutfitEmptyState(
                          hasWardrobe: wardrobeCount > 0,
                          onGetStarted: _openGetStartedFlow,
                          onTryOn: () => context
                              .read<NavigationProvider>()
                              .navigateToTryOn(),
                        )
                      : _suggestionsLoading && !_suggestionsLoaded
                          ? const _DailyOutfitLoadingState()
                          : _outfits.isEmpty
                              ? _DailyOutfitNeedMoreItemsState(
                                  onUpload: _openGetStartedFlow,
                                )
                              : _DailyOutfitPager(
                                  controller: _outfitController,
                                  outfits: _outfits,
                                  index: _outfitIndex,
                                  onIndexChanged: (i) =>
                                      setState(() => _outfitIndex = i),
                                  onTryOn: () => context
                                      .read<NavigationProvider>()
                                      .navigateToTryOn(),
                                  onPrev: () => _outfitController.previousPage(
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  ),
                                  onNext: () => _outfitController.nextPage(
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                ),
              ),
            ),

            // 3) Quick access 2x2
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 1,
                  child: const SectionHeader(
                    title: 'Quick Access',
                    subtitle: 'Jump into your key style tools',
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Taller cells so title/subtitle don't overflow on small phones.
                  childAspectRatio: 1.02,
                ),
                delegate: SliverChildListDelegate.fixed(
                  [
                    StaggeredFadeIn(
                      index: 3,
                      child: _QuickCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Outfit Generator',
                        subtitle: 'Build & save combos',
                        onTap: _openOutfitGenerator,
                      ),
                    ),
                    StaggeredFadeIn(
                      index: 4,
                      child: _QuickCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Friends & Community',
                        subtitle: 'Inspiration feed',
                        onTap: () =>
                            context.read<NavigationProvider>().navigateToCommunity(),
                      ),
                    ),
                    StaggeredFadeIn(
                      index: 5,
                      child: _QuickCard(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Wishlist',
                        subtitle: 'Save fits you love',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        ),
                      ),
                    ),
                    StaggeredFadeIn(
                      index: 6,
                      child: _QuickCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Trending Styles',
                        subtitle: 'What’s hot today',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TrendingStylesScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4) Wardrobe progress
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 7,
                  child: _WardrobeProgressCard(
                    completion: totalItems == 0
                        ? 0
                        : (totalItems / 50).clamp(0.0, 1.0),
                    totalItems: totalItems,
                    avatarReady: false,
                    onBuildWardrobe: _openGetStartedFlow,
                  ),
                ),
              ),
            ),

            // 5) Stories (Style community section)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 8,
                  child: const SectionHeader(
                    title: 'Style Community',
                    subtitle: 'Stories from your world',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StaggeredFadeIn(
                index: 9,
                child: _StoryRow(
                  items: const [
                    _StoryItem(label: 'Create Post', icon: Icons.add_rounded),
                    _StoryItem(label: 'Inspiration', icon: Icons.lightbulb_rounded),
                    _StoryItem(label: 'Office Looks', icon: Icons.work_rounded),
                    _StoryItem(label: 'Casual', icon: Icons.weekend_rounded),
                    _StoryItem(label: 'Streetwear', icon: Icons.skateboarding_rounded),
                    _StoryItem(label: 'Party Looks', icon: Icons.celebration_rounded),
                  ],
                ),
              ),
            ),

            // 6) Community feed preview with tabs (segmented)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 10,
                  child: _CommunityFeedPreview(
                    onOpenCommunity: () =>
                        context.read<NavigationProvider>().navigateToCommunity(),
                  ),
                ),
              ),
            ),

            // 7) Share banner
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 11,
                  child: _ShareBanner(
                    onShare: () =>
                        context.read<NavigationProvider>().navigateToCommunity(),
                  ),
                ),
              ),
            ),

            // 8) Closet analytics
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 12,
                  child: const SectionHeader(
                    title: 'Closet Analytics',
                    subtitle: 'What you wear (and what you don’t)',
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 13,
                  child: Column(
                    children: [
                      _ClosetUsageRow(
                        title: 'Most Used Items',
                        icon: Icons.local_fire_department_rounded,
                        items: _mostUsedItems,
                        loading: _analyticsLoading,
                        emptyMessage: 'Wear items from your wardrobe to see stats here.',
                      ),
                      const SizedBox(height: 12),
                      _ClosetUsageRow(
                        title: 'Least Used Items',
                        icon: Icons.timelapse_rounded,
                        items: _leastUsedItems,
                        loading: _analyticsLoading,
                        emptyMessage: 'All items are getting good rotation!',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 9) Outfit planner
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 16,
                  child: const SectionHeader(
                    title: 'Outfit Planner',
                    subtitle: 'Your week, styled in advance',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StaggeredFadeIn(
                index: 17,
                child: _OutfitPlannerRow(
                  items: _weekPlan,
                  loading: _plannerLoading,
                  onOpenGenerator: _openOutfitGenerator,
                ),
              ),
            ),

            // 11) Events planner
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 18,
                  child: _EventsCard(
                    events: _upcomingEvents,
                    loading: _eventsLoading,
                    onSchedule: _openEventsPlanner,
                    onEventTap: (event) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(
                            eventId: event.id,
                            initial: event,
                          ),
                        ),
                      );
                      if (mounted) await _loadUpcomingEvents();
                    },
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: 22 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
    );
  }
}

@immutable
class _DailyOutfit {
  final String title;
  final int matchPercent;
  final String occasion;
  final String note;
  final List<Cloth> items;
  final String setLabel;

  const _DailyOutfit({
    required this.title,
    required this.matchPercent,
    required this.occasion,
    required this.note,
    required this.items,
    required this.setLabel,
  });
}

class _DailyOutfitPager extends StatelessWidget {
  final PageController controller;
  final List<_DailyOutfit> outfits;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onTryOn;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DailyOutfitPager({
    required this.controller,
    required this.outfits,
    required this.index,
    required this.onIndexChanged,
    required this.onTryOn,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Daily Outfit Suggestion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (outfits.length > 1) ...[
                IconButton(
                  onPressed: onPrev,
                  tooltip: 'Previous outfit',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: onNext,
                  tooltip: 'Next outfit',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: controller,
            itemCount: outfits.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, i) {
              final o = outfits[i];
              final scheme = Theme.of(context).colorScheme;
              final textTheme = Theme.of(context).textTheme;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: MediaQuery.textScalerOf(context).clamp(
                      minScaleFactor: 0.85,
                      maxScaleFactor: 1.1,
                    ),
                  ),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'daily_outfit_$i',
                          child: _OutfitCollage(items: o.items),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: _OccasionPill(text: o.occasion),
                                  ),
                                  const SizedBox(width: 6),
                                  _SetPill(text: o.setLabel),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                o.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                o.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.72),
                                  height: 1.2,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  _MatchPill(percent: o.matchPercent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: onTryOn,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Try On Avatar'),
                                        ),
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
                  ),
                ),
              );
            },
          ),
        ),
        if (outfits.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              outfits.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == index ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: i == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DailyOutfitLoadingState extends StatelessWidget {
  const _DailyOutfitLoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daily Outfit Suggestion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Styling today’s looks from your closet…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyOutfitNeedMoreItemsState extends StatelessWidget {
  final VoidCallback onUpload;

  const _DailyOutfitNeedMoreItemsState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daily Outfit Suggestion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PremiumCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a few more pieces',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload at least 2 wearable items so we can build outfit sets for today.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onUpload,
                    child: const Text('Upload more clothes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyOutfitEmptyState extends StatelessWidget {
  final bool hasWardrobe;
  final VoidCallback onGetStarted;
  final VoidCallback onTryOn;

  const _DailyOutfitEmptyState({
    required this.hasWardrobe,
    required this.onGetStarted,
    required this.onTryOn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daily Outfit Suggestion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PremiumCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(WardrobeTokens.radiusMd),
                        border: Border.all(color: WardrobeTokens.outlineGold),
                        color: scheme.primary.withValues(alpha: 0.16),
                      ),
                      child: Icon(
                        Icons.checkroom_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasWardrobe
                                ? 'Your closet is empty'
                                : 'Start your wardrobe',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasWardrobe
                                ? 'Upload your clothes with Try On AI so we can suggest daily outfits for you.'
                                : 'Please create a wardrobe and upload your clothes with help of Try On AI to unlock daily outfit suggestions.',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.72),
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    key: const ValueKey('daily_outfit_get_started'),
                    onPressed: onGetStarted,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasWardrobe
                              ? Icons.add_a_photo_outlined
                              : Icons.create_new_folder_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            hasWardrobe
                                ? 'Upload clothes with Try On AI'
                                : 'Create wardrobe & upload clothes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: Material(
                    key: const ValueKey('daily_outfit_open_tryon'),
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTryOn,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Open Try-On',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutfitCollage extends StatelessWidget {
  final List<Cloth> items;
  const _OutfitCollage({required this.items});

  String _imageUrl(Cloth cloth) {
    final processed = cloth.processedImageUrl?.trim();
    if (processed != null && processed.isNotEmpty) return processed;
    return cloth.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previews = items.take(3).toList();

    return Container(
      width: 110,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WardrobeTokens.radiusLg),
        border: Border.all(color: WardrobeTokens.outlineGold),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.20),
            const Color(0xFF06211C),
          ],
        ),
      ),
      child: Stack(
        children: [
          if (previews.isNotEmpty)
            Positioned(
              left: 10,
              top: 12,
              child: _CollageImageTile(
                size: 44,
                imageUrl: _imageUrl(previews[0]),
              ),
            ),
          if (previews.length > 1)
            Positioned(
              right: 10,
              top: 56,
              child: _CollageImageTile(
                size: 38,
                imageUrl: _imageUrl(previews[1]),
              ),
            ),
          if (previews.length > 2)
            Positioned(
              left: 18,
              bottom: 18,
              child: _CollageImageTile(
                size: 46,
                imageUrl: _imageUrl(previews[2]),
              ),
            )
          else
            Positioned(
              left: 18,
              bottom: 18,
              child: _CollageTile(
                size: 46,
                icon: Icons.checkroom_rounded,
                color: scheme.primary,
              ),
            ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: scheme.primary.withValues(alpha: 0.75),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollageImageTile extends StatelessWidget {
  final double size;
  final String imageUrl;

  const _CollageImageTile({required this.size, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl.trim().isEmpty
              ? ColoredBox(
                  color: scheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.checkroom_rounded,
                    color: scheme.primary,
                    size: size * 0.45,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.10),
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.checkroom_rounded,
                      color: scheme.primary,
                      size: size * 0.45,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color color;
  const _CollageTile({required this.size, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(icon, color: color, size: size * 0.55),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF06231E),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: WardrobeTokens.outlineGold),
      ),
      child: child,
    );
  }
}

class _SetPill extends StatelessWidget {
  final String text;
  const _SetPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.secondary,
            ),
      ),
    );
  }
}

class _OccasionPill extends StatelessWidget {
  final String text;
  const _OccasionPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }
}

class _MatchPill extends StatelessWidget {
  final int percent;
  const _MatchPill({required this.percent});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$percent% Match',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.1,
        ),
      ),
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    const Color(0xFF06211C),
                  ],
                ),
                border: Border.all(color: WardrobeTokens.outlineGold),
              ),
              child: Icon(icon, color: scheme.primary, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.72),
                height: 1.15,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _WardrobeProgressCard extends StatelessWidget {
  final double completion;
  final int totalItems;
  final bool avatarReady;
  final VoidCallback onBuildWardrobe;

  const _WardrobeProgressCard({
    required this.completion,
    required this.totalItems,
    required this.avatarReady,
    required this.onBuildWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Your Closet Awaits',
            subtitle: 'Grow your wardrobe for smarter AI styling',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Closet completion',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completion,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(completion * 100).round()}% complete',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WardrobeTokens.outlineGold),
                  color: const Color(0xFF06231E),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalItems',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      'items uploaded',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          avatarReady ? Icons.verified_rounded : Icons.info_outline_rounded,
                          size: 16,
                          color: avatarReady ? scheme.primary : scheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          avatarReady ? 'Avatar ready' : 'Avatar pending',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface.withValues(alpha: 0.86),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onBuildWardrobe,
              child: const Text('Build My Wardrobe'),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _StoryItem {
  final String label;
  final IconData icon;
  const _StoryItem({required this.label, required this.icon});
}

class _StoryRow extends StatelessWidget {
  final List<_StoryItem> items;
  const _StoryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final it = items[i];
          return SizedBox(
            width: 74,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.22),
                        const Color(0xFF06211C),
                      ],
                    ),
                    border: Border.all(color: WardrobeTokens.outlineGold),
                  ),
                  child: Icon(it.icon, color: scheme.primary, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  it.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

enum _FeedTab { your, saved, all }

extension _FeedTabApi on _FeedTab {
  String get apiScope => switch (this) {
        _FeedTab.your => 'mine',
        _FeedTab.saved => 'saved',
        _FeedTab.all => 'all',
      };

  String get label => switch (this) {
        _FeedTab.your => 'Your Style',
        _FeedTab.saved => 'Saved',
        _FeedTab.all => 'All Styles',
      };
}

class _CommunityFeedPreview extends StatefulWidget {
  final VoidCallback onOpenCommunity;
  const _CommunityFeedPreview({required this.onOpenCommunity});

  @override
  State<_CommunityFeedPreview> createState() => _CommunityFeedPreviewState();
}

class _CommunityFeedPreviewState extends State<_CommunityFeedPreview> {
  static const _previewCount = 2;

  _FeedTab _tab = _FeedTab.all;
  bool _loading = true;
  String? _error;
  List<StylePost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts =
          await StylePostService.getPosts(scope: _tab.apiScope);
      if (!mounted) return;
      setState(() {
        _posts = posts.take(_previewCount).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(StylePost post) async {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;

    final wasLiked = post.likedByMe;
    setState(() {
      _posts[idx] = post.copyWith(
        likedByMe: !wasLiked,
        likesCount: (post.likesCount + (wasLiked ? -1 : 1)).clamp(0, 999999),
      );
    });

    try {
      if (wasLiked) {
        await StylePostService.unlike(post.id);
        if (_tab == _FeedTab.saved && mounted) {
          setState(() => _posts.removeAt(idx));
        }
      } else {
        await StylePostService.like(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _posts[idx] = post);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like failed: $e')),
      );
    }
  }

  Future<void> _toggleWishlist(StylePost post) async {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;

    final wasWishlisted = post.wishlistedByMe;
    setState(() {
      _posts[idx] = post.copyWith(wishlistedByMe: !wasWishlisted);
    });

    try {
      if (wasWishlisted) {
        await StylePostService.removeFromWishlist(post.id);
      } else {
        await StylePostService.addToWishlist(post.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to wishlist')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _posts[idx] = post);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Community Feed',
            subtitle: 'Luxury looks, real people',
            trailing: TextButton(
              onPressed: widget.onOpenCommunity,
              child: Text(
                'Open',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_FeedTab>(
            segments: _FeedTab.values
                .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                .toList(),
            selected: {_tab},
            onSelectionChanged: (s) {
              setState(() => _tab = s.first);
              _loadPosts();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return scheme.primary.withValues(alpha: 0.16);
                }
                return Colors.white.withValues(alpha: 0.05);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return scheme.primary;
                return scheme.onSurface.withValues(alpha: 0.86);
              }),
              side: const WidgetStatePropertyAll(
                BorderSide(color: WardrobeTokens.outlineGold, width: 1),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildFeedBody(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBody(ColorScheme scheme) {
    if (_loading) {
      return const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              'Could not load style posts',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _loadPosts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Padding(
        key: ValueKey('empty-${_tab.name}'),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 36, color: scheme.primary.withValues(alpha: 0.75)),
            const SizedBox(height: 10),
            Text(
              _emptyTitle(),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _emptySubtitle(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onOpenCommunity,
              child: const Text('Open Style Feed'),
            ),
          ],
        ),
      );
    }

    return Column(
      key: ValueKey('posts-${_tab.name}-${_posts.map((p) => p.id).join()}'),
      children: [
        for (var i = 0; i < _posts.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _FeedCard(
            post: _posts[i],
            onTap: widget.onOpenCommunity,
            onLike: () => _toggleLike(_posts[i]),
            onWishlist: () => _toggleWishlist(_posts[i]),
          ),
        ],
      ],
    );
  }

  String _emptyTitle() => switch (_tab) {
        _FeedTab.your => 'No style posts yet',
        _FeedTab.saved => 'Nothing saved yet',
        _FeedTab.all => 'No styles to show yet',
      };

  String _emptySubtitle() => switch (_tab) {
        _FeedTab.your => 'Post your first look in Style Community.',
        _FeedTab.saved => 'Like posts in the feed to save them here.',
        _FeedTab.all => 'Be the first to share a look with friends.',
      };
}

class _FeedCard extends StatelessWidget {
  final StylePost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onWishlist;

  const _FeedCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onWishlist,
  });

  static String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final username = post.user?.displayLabel ?? 'User';
    final timeAgo = _timeAgo(post.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WardrobeTokens.outlineGold),
            color: const Color(0xFF06231E),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primary.withValues(alpha: 0.18),
                      backgroundImage: (post.user?.photoUrl != null &&
                              post.user!.photoUrl!.isNotEmpty)
                          ? NetworkImage(post.user!.photoUrl!)
                          : null,
                      child: (post.user?.photoUrl == null ||
                              post.user!.photoUrl!.isEmpty)
                          ? Icon(Icons.person_rounded,
                              color: scheme.primary, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        username,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    if (onWishlist != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: post.wishlistedByMe
                            ? 'Remove from wishlist'
                            : 'Add to wishlist',
                        onPressed: onWishlist,
                        icon: Icon(
                          post.wishlistedByMe
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: post.wishlistedByMe
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.75),
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: scheme.primary.withValues(alpha: 0.08),
                  child: post.imageUrl.isEmpty
                      ? Center(
                          child: Icon(
                            Icons.photo_camera_back_rounded,
                            color: scheme.primary.withValues(alpha: 0.75),
                            size: 34,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: post.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          placeholder: (_, __) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                ),
              ),
              if (post.caption != null && post.caption!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    post.caption!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onLike,
                      icon: Icon(
                        post.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: post.likedByMe
                            ? Colors.redAccent
                            : scheme.primary,
                        size: 20,
                      ),
                    ),
                    Text(
                      '${post.likesCount}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.mode_comment_outlined,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${post.commentsCount}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        size: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareBanner extends StatelessWidget {
  final VoidCallback onShare;
  const _ShareBanner({required this.onShare});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onShare,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.95),
                scheme.secondary.withValues(alpha: 0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share your style',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Post outfits, save inspirations, build your community.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimary.withValues(alpha: 0.14),
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: scheme.onPrimary.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: onShare,
                child: const Text('Share Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankedCloth {
  final Cloth cloth;
  final int wearCount;
  final DateTime? lastWorn;

  const _RankedCloth({
    required this.cloth,
    required this.wearCount,
    this.lastWorn,
  });
}

class _ClosetUsageRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_RankedCloth> items;
  final bool loading;
  final String emptyMessage;

  const _ClosetUsageRow({
    required this.title,
    required this.icon,
    required this.items,
    required this.loading,
    required this.emptyMessage,
  });

  String _imageUrl(Cloth cloth) {
    if (cloth.processedImageUrl != null &&
        cloth.processedImageUrl!.isNotEmpty) {
      return cloth.processedImageUrl!;
    }
    return cloth.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (items.isEmpty)
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final ranked = items[i];
                  final cloth = ranked.cloth;
                  final url = _imageUrl(cloth);
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ClothDetailScreen(
                            cloth: cloth,
                            isOwner: true,
                          ),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 88,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: WardrobeTokens.outlineGold,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: url.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorWidget: (_, __, ___) => ColoredBox(
                                          color: scheme.primary
                                              .withValues(alpha: 0.1),
                                          child: const Icon(Icons.checkroom),
                                        ),
                                      )
                                    : ColoredBox(
                                        color: scheme.primary
                                            .withValues(alpha: 0.1),
                                        child: const Icon(Icons.checkroom),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cloth.clothType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            ranked.wearCount == 0
                                ? 'Never worn'
                                : '${ranked.wearCount} wear${ranked.wearCount == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.65),
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OutfitPlannerRow extends StatelessWidget {
  final List<({String dayKey, String dayLabel, SavedOutfit? outfit})> items;
  final bool loading;
  final VoidCallback onOpenGenerator;

  const _OutfitPlannerRow({
    required this.items,
    required this.loading,
    required this.onOpenGenerator,
  });

  List<String> _previewUrls(SavedOutfit outfit) {
    final urls = <String>[];
    for (final key in OutfitSlots.all) {
      final item = outfit.slotItems[key];
      if (item != null && item.displayImageUrl.isNotEmpty) {
        urls.add(item.displayImageUrl);
      }
    }
    return urls.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 176,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final it = items[i];
          final outfit = it.outfit;
          final previews = outfit != null ? _previewUrls(outfit) : const <String>[];
          final isToday = it.dayKey == OutfitPlannerDays.todayKey();

          return SizedBox(
            width: 160,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(context).clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.1,
                ),
              ),
              child: PremiumCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isToday ? scheme.secondary : scheme.primary,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Today',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenGenerator,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WardrobeTokens.outlineGold),
                            color: const Color(0xFF041E1A),
                          ),
                          child: previews.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        color: scheme.primary
                                            .withValues(alpha: 0.75),
                                        size: 26,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add look',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.65),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.count(
                                  crossAxisCount: 2,
                                  padding: const EdgeInsets.all(4),
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: previews
                                      .map(
                                        (url) => ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                ColoredBox(
                                              color: scheme.primary
                                                  .withValues(alpha: 0.1),
                                              child: const Icon(
                                                  Icons.checkroom, size: 16),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      outfit?.name ?? 'Plan a look',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: outfit == null
                            ? scheme.onSurface.withValues(alpha: 0.55)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  final List<PlannedEvent> events;
  final bool loading;
  final VoidCallback onSchedule;
  final void Function(PlannedEvent event) onEventTap;

  const _EventsCard({
    required this.events,
    required this.loading,
    required this.onSchedule,
    required this.onEventTap,
  });

  IconData _iconForOccasion(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('wedding') || t.contains('engagement')) {
      return Icons.favorite_rounded;
    }
    if (t.contains('diwali') ||
        t.contains('holi') ||
        t.contains('festival') ||
        t.contains('christmas')) {
      return Icons.celebration_rounded;
    }
    if (t.contains('office') || t.contains('formal')) {
      return Icons.business_center_rounded;
    }
    return Icons.event_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Events Planner',
            subtitle: 'Dress for what’s coming up',
            trailing: TextButton(
              onPressed: onSchedule,
              child: Text(
                events.isEmpty ? 'Schedule' : 'View all',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (events.isEmpty)
            GestureDetector(
              onTap: onSchedule,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WardrobeTokens.outlineGold),
                  color: const Color(0xFF06231E),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 36,
                      color: scheme.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Schedule your event',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a festival, wedding, or party — get outfit suggestions from your wardrobe tags.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...events.take(3).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onEventTap(e),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: WardrobeTokens.outlineGold),
                            color: const Color(0xFF06231E),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color:
                                      scheme.primary.withValues(alpha: 0.14),
                                  border: Border.all(
                                      color: WardrobeTokens.outlineGold),
                                ),
                                child: Icon(
                                  _iconForOccasion(e.occasionTag),
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.occasionTag} · ${e.dateLabel}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.72),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (e.suggestions.isNotEmpty)
                                      Text(
                                        '${e.suggestions.length} outfit picks',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

