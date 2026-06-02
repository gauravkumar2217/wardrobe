import 'package:flutter/material.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../widgets/premium/premium_card.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: WardrobeTokens.emeraldBg,
            child: TabBar(
              indicatorColor: scheme.primary,
              labelColor: scheme.primary,
              unselectedLabelColor:
                  scheme.onSurface.withValues(alpha: 0.7),
              tabs: const [
                Tab(text: 'Your Style'),
                Tab(text: 'Saved'),
                Tab(text: 'All Styles'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _CommunityTabFeed(mode: _CommunityFeedMode.your),
                const _CommunityTabFeed(mode: _CommunityFeedMode.saved),
                const _CommunityTabFeed(mode: _CommunityFeedMode.all),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CommunityFeedMode { your, saved, all }

class _CommunityTabFeed extends StatelessWidget {
  final _CommunityFeedMode mode;
  const _CommunityTabFeed({required this.mode});

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      _CommunityFeedMode.your => 'Your Style',
      _CommunityFeedMode.saved => 'Saved',
      _CommunityFeedMode.all => 'All Styles',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _StoryRow(
          items: const [
            _StoryItem(label: 'Create Post', icon: Icons.add_rounded),
            _StoryItem(label: 'Inspiration', icon: Icons.lightbulb_rounded),
            _StoryItem(label: 'Office', icon: Icons.work_rounded),
            _StoryItem(label: 'Casual', icon: Icons.weekend_rounded),
            _StoryItem(label: 'Street', icon: Icons.skateboarding_rounded),
            _StoryItem(label: 'Party', icon: Icons.celebration_rounded),
          ],
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                child: Icon(
                  Icons.people_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$title feed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Icon(Icons.tune_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FeedCard(
          username: mode == _CommunityFeedMode.saved ? 'SavedLooks' : 'AishaStyles',
          timeAgo: '2h',
          likeCount: 1240,
          commentCount: 84,
        ),
        const SizedBox(height: 12),
        _FeedCard(
          username: mode == _CommunityFeedMode.all ? 'StreetLux' : 'OfficeMuse',
          timeAgo: '6h',
          likeCount: 630,
          commentCount: 41,
        ),
      ],
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
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          return Column(
            children: [
              Container(
                width: 58,
                height: 58,
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
              const SizedBox(height: 6),
              SizedBox(
                width: 64,
                child: Text(
                  it.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
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
    return PremiumCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
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
            height: 190,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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

