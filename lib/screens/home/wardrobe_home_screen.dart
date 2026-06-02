import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/navigation_provider.dart';
import '../../theme/wardrobe_tokens.dart';
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

  final _outfits = const <_DailyOutfit>[
    _DailyOutfit(
      title: 'Smart Casual',
      matchPercent: 95,
      tempC: 28,
      occasion: 'Office',
      note: 'Perfect for office weather',
      accentIcon: Icons.work_outline_rounded,
    ),
    _DailyOutfit(
      title: 'Street Minimal',
      matchPercent: 92,
      tempC: 26,
      occasion: 'Casual',
      note: 'Clean lines, effortless layers',
      accentIcon: Icons.directions_walk_rounded,
    ),
    _DailyOutfit(
      title: 'Evening Chic',
      matchPercent: 90,
      tempC: 24,
      occasion: 'Dinner',
      note: 'Gold accents, sleek silhouette',
      accentIcon: Icons.wine_bar_rounded,
    ),
  ];

  @override
  void dispose() {
    _outfitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
            // Daily outfit suggestion card (pageable)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 0,
                  child: _DailyOutfitPager(
                    controller: _outfitController,
                    outfits: _outfits,
                    index: _outfitIndex,
                    onIndexChanged: (i) => setState(() => _outfitIndex = i),
                    onTryOn: () =>
                        context.read<NavigationProvider>().navigateToTryOn(),
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
                  childAspectRatio: 1.18,
                ),
                delegate: SliverChildListDelegate.fixed(
                  [
                    StaggeredFadeIn(
                      index: 3,
                      child: _QuickCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Outfit Generator',
                        subtitle: 'AI outfit ideas',
                        onTap: () {},
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
                        onTap: () {},
                      ),
                    ),
                    StaggeredFadeIn(
                      index: 6,
                      child: _QuickCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Trending Styles',
                        subtitle: 'What’s hot today',
                        onTap: () {},
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
                    completion: 0.42,
                    totalItems: 37,
                    avatarReady: false,
                    onBuildWardrobe: () {},
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
                  child: _ShareBanner(onShare: () {}),
                ),
              ),
            ),

            // 8) Fashion insights
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 12,
                  child: const SectionHeader(
                    title: 'Fashion Insights',
                    subtitle: 'Personalized style intelligence',
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 13,
                  child: Row(
                    children: const [
                      Expanded(child: _StyleScoreCard(score: 86)),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MoodBoardCard(
                          categories: ['Minimal', 'Smart', 'Street', 'Classic'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 9) Closet analytics
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 14,
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
                  index: 15,
                  child: Row(
                    children: const [
                      Expanded(
                        child: _AnalyticsMiniCard(
                          title: 'Most Used Items',
                          items: ['Shirt', 'Sneakers'],
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _AnalyticsMiniCard(
                          title: 'Least Used Items',
                          items: ['Jacket', 'Formal Shoes'],
                          icon: Icons.timelapse_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 10) Outfit planner
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
                  items: const [
                    _PlannedOutfit(day: 'Monday', title: 'Monochrome Layers'),
                    _PlannedOutfit(day: 'Tuesday', title: 'Smart Casual'),
                    _PlannedOutfit(day: 'Wednesday', title: 'Street Minimal'),
                  ],
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
                    events: const [
                      _EventItem(
                        title: 'Dinner Date',
                        dateLabel: 'Fri, 7:30 PM',
                        icon: Icons.restaurant_rounded,
                      ),
                      _EventItem(
                        title: 'Office Meeting',
                        dateLabel: 'Mon, 10:00 AM',
                        icon: Icons.meeting_room_rounded,
                      ),
                      _EventItem(
                        title: 'Friend Party',
                        dateLabel: 'Sat, 9:00 PM',
                        icon: Icons.celebration_rounded,
                      ),
                    ],
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
  final int tempC;
  final String occasion;
  final String note;
  final IconData accentIcon;

  const _DailyOutfit({
    required this.title,
    required this.matchPercent,
    required this.tempC,
    required this.occasion,
    required this.note,
    required this.accentIcon,
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PremiumCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'daily_outfit_$i',
                        child: _OutfitCollage(accentIcon: o.accentIcon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _OccasionPill(text: o.occasion),
                                const SizedBox(width: 8),
                                _WeatherPill(tempC: o.tempC),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              o.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              o.note,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.72),
                                  ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                _MatchPill(percent: o.matchPercent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: onTryOn,
                                      child: const Text('Try On Avatar'),
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
              );
            },
          ),
        ),
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
    );
  }
}

class _OutfitCollage extends StatelessWidget {
  final IconData accentIcon;
  const _OutfitCollage({required this.accentIcon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Positioned(
            left: 10,
            top: 12,
            child: _CollageTile(
              size: 44,
              icon: Icons.checkroom_rounded,
              color: scheme.primary,
            ),
          ),
          Positioned(
            right: 10,
            top: 56,
            child: _CollageTile(
              size: 38,
              icon: Icons.snowshoeing_rounded,
              color: scheme.secondary,
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: _CollageTile(
              size: 46,
              icon: accentIcon,
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

class _WeatherPill extends StatelessWidget {
  final int tempC;
  const _WeatherPill({required this.tempC});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_sunny_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$tempC°C',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
            child: Icon(icon, color: scheme.primary),
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
      height: 106,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final it = items[i];
          return Column(
            children: [
              Container(
                width: 62,
                height: 62,
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
                child: Icon(it.icon, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 74,
                child: Text(
                  it.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

enum _FeedTab { your, saved, all }

class _CommunityFeedPreview extends StatefulWidget {
  final VoidCallback onOpenCommunity;
  const _CommunityFeedPreview({required this.onOpenCommunity});

  @override
  State<_CommunityFeedPreview> createState() => _CommunityFeedPreviewState();
}

class _CommunityFeedPreviewState extends State<_CommunityFeedPreview> {
  _FeedTab _tab = _FeedTab.your;

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
            segments: const [
              ButtonSegment(value: _FeedTab.your, label: Text('Your Style')),
              ButtonSegment(value: _FeedTab.saved, label: Text('Saved')),
              ButtonSegment(value: _FeedTab.all, label: Text('All Styles')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
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
            child: Column(
              key: ValueKey(_tab),
              children: [
                _FeedCard(
                  username: _tab == _FeedTab.saved ? 'SavedLooks' : 'AishaStyles',
                  timeAgo: '2h',
                  likeCount: 1240,
                  commentCount: 84,
                ),
                const SizedBox(height: 12),
                _FeedCard(
                  username: _tab == _FeedTab.all ? 'StreetLux' : 'OfficeMuse',
                  timeAgo: '6h',
                  likeCount: 630,
                  commentCount: 41,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final String username;
  final String timeAgo;
  final int likeCount;
  final int commentCount;

  const _FeedCard({
    required this.username,
    required this.timeAgo,
    required this.likeCount,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
                  child: Icon(Icons.person_rounded, color: scheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    username,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.bookmark_border_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.75), size: 20),
              ],
            ),
          ),
          Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
                  const Color(0xFF041E1A),
                ],
              ),
              border: Border.all(color: WardrobeTokens.outlineGold),
            ),
            child: Center(
              child: Icon(
                Icons.photo_camera_back_rounded,
                color: scheme.primary.withValues(alpha: 0.75),
                size: 34,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Icon(Icons.favorite_border_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$likeCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.mode_comment_outlined,
                    color: scheme.onSurface.withValues(alpha: 0.85), size: 20),
                const SizedBox(width: 8),
                Text(
                  '$commentCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Icon(Icons.ios_share_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.85), size: 20),
              ],
            ),
          ),
        ],
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
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: onShare,
            child: const Text('Share Now'),
          ),
        ],
      ),
    );
  }
}

class _StyleScoreCard extends StatelessWidget {
  final int score;
  const _StyleScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                  Text(
                    '$score/100',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Consistency + fit balance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _MoodBoardCard extends StatelessWidget {
  final List<String> categories;
  const _MoodBoardCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Mood Board',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: WardrobeTokens.outlineGold),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Text(
                      c,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface.withValues(alpha: 0.9),
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Top recommended categories',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMiniCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;

  const _AnalyticsMiniCard({
    required this.title,
    required this.items,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_rounded,
                      size: 18, color: scheme.secondary.withValues(alpha: 0.95)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _PlannedOutfit {
  final String day;
  final String title;
  const _PlannedOutfit({required this.day, required this.title});
}

class _OutfitPlannerRow extends StatelessWidget {
  final List<_PlannedOutfit> items;
  const _OutfitPlannerRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 168,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final it = items[i];
          return SizedBox(
            width: 180,
            child: PremiumCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.day,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: WardrobeTokens.outlineGold),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.14),
                          const Color(0xFF041E1A),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.checkroom_rounded,
                          color: scheme.primary.withValues(alpha: 0.78), size: 30),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
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

@immutable
class _EventItem {
  final String title;
  final String dateLabel;
  final IconData icon;
  const _EventItem({
    required this.title,
    required this.dateLabel,
    required this.icon,
  });
}

class _EventsCard extends StatelessWidget {
  final List<_EventItem> events;
  const _EventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Events Planner',
            subtitle: 'Dress for what’s coming up',
          ),
          const SizedBox(height: 12),
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WardrobeTokens.outlineGold),
                  color: const Color(0xFF06231E),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: scheme.primary.withValues(alpha: 0.14),
                        border: Border.all(color: WardrobeTokens.outlineGold),
                      ),
                      child: Icon(e.icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.dateLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurface.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

