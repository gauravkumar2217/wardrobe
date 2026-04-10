import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/banner_service.dart';
import '../../widgets/banner_slider_widget.dart';
import '../notifications/notifications_screen.dart';
import '../profile/settings_screen.dart';
import '../scheduler/scheduler_list_screen.dart';
import '../suggestions/daily_suggestion_screen.dart';
import '../statistics/statistics_screen.dart';
import 'clothes_screen.dart';
import '../../models/banner.dart' as models;

/// Main [HomeScreen]: logo header and feature cards (bottom tab Home).
class HomeScreen extends StatefulWidget {
  /// When true (e.g. opened from Profile), shows an app bar with back.
  final bool showAppBar;

  const HomeScreen({super.key, this.showAppBar = false});

  static const Color _brand = Color(0xFF043915);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bannerRefreshToken = 0;

  Future<void> _refresh() async {
    setState(() {
      _bannerRefreshToken++;
    });
    // Give the header time to start its reload; RefreshIndicator expects a Future.
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final features = <_HomeFeature>[
      _HomeFeature(
        icon: Icons.swipe_vertical_rounded,
        title: 'Clothes',
        subtitle: 'Swipe full-screen through your closet',
        color: const Color(0xFF1B5E20),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const ClothesScreen()),
        ),
      ),
      _HomeFeature(
        icon: Icons.inventory_2_rounded,
        title: 'Wardrobes',
        subtitle: 'Organize your collections',
        color: const Color(0xFF2E7D32),
        onTap: (ctx) => _goTab(ctx, 1),
      ),
      // _HomeFeature(
      //   icon: Icons.auto_awesome_rounded,
      //   title: 'Changing room',
      //   subtitle: 'Try outfits on your avatar',
      //   color: const Color(0xFF6A1B9A),
      //   // Disabled for now: my Gemini API key is suspended, so I can't use this feature.
      //   // Re-enable once a new Gemini API key is generated and configured.
      //   onTap: (ctx) => Navigator.push(
      //     ctx,
      //     MaterialPageRoute(builder: (_) => const ChangingRoomScreen()),
      //   ),
      // ),
      _HomeFeature(
        icon: Icons.lightbulb_rounded,
        title: 'Daily suggestion',
        subtitle: 'See your outfit ideas for today',
        color: const Color(0xFF00897B),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const DailySuggestionScreen()),
        ),
      ),
      _HomeFeature(
        icon: Icons.event_available_rounded,
        title: 'Scheduler',
        subtitle: 'Outfit reminders & plans',
        color: const Color(0xFF00695C),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const SchedulerListScreen()),
        ),
      ),
      _HomeFeature(
        icon: Icons.people_rounded,
        title: 'Friends',
        subtitle: 'Connect and share',
        color: const Color(0xFF1565C0),
        onTap: (ctx) => _goTab(ctx, 2),
      ),
      _HomeFeature(
        icon: Icons.chat_bubble_rounded,
        title: 'Chats',
        subtitle: 'Messages',
        color: const Color(0xFFC62828),
        onTap: (ctx) => _goTab(ctx, 3),
      ),
      _HomeFeature(
        icon: Icons.notifications_active_rounded,
        title: 'Notifications',
        subtitle: 'Alerts and activity',
        color: const Color(0xFFEF6C00),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      _HomeFeature(
        icon: Icons.bar_chart_rounded,
        title: 'Statistics',
        subtitle: 'Wear insights',
        color: const Color(0xFF455A64),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const StatisticsScreen()),
        ),
      ),
      _HomeFeature(
        icon: Icons.person_rounded,
        title: 'Profile',
        subtitle: 'Account and avatar',
        color: const Color(0xFF37474F),
        onTap: (ctx) => _goTab(ctx, 4),
      ),
      _HomeFeature(
        icon: Icons.settings_rounded,
        title: 'Settings',
        subtitle: 'Preferences and privacy',
        color: const Color(0xFF546E7A),
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Home'),
              backgroundColor: HomeScreen._brand,
              foregroundColor: Colors.white,
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F0E8),
              Color(0xFFF5F7F4),
              Color(0xFFF0F4F1),
            ],
          ),
        ),
        child: SafeArea(
          top: !widget.showAppBar,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    brand: HomeScreen._brand,
                    refreshToken: _bannerRefreshToken,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.98,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = features[index];
                        return _FeatureCard(
                          icon: f.icon,
                          title: f.title,
                          subtitle: f.subtitle,
                          accent: f.color,
                          onTap: () => f.onTap(context),
                        );
                      },
                      childCount: features.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _goTab(BuildContext context, int index) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    Provider.of<NavigationProvider>(context, listen: false)
        .setCurrentIndex(index);
  }
}

class _HomeFeature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final void Function(BuildContext context) onTap;

  _HomeFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _HomeHeader extends StatelessWidget {
  final Color brand;
  final int refreshToken;

  const _HomeHeader({required this.brand, required this.refreshToken});

  @override
  Widget build(BuildContext context) {
    return _HomeHeaderBody(brand: brand, refreshToken: refreshToken);
  }
}

class _HomeHeaderBody extends StatefulWidget {
  final Color brand;
  final int refreshToken;

  const _HomeHeaderBody({required this.brand, required this.refreshToken});

  @override
  State<_HomeHeaderBody> createState() => _HomeHeaderBodyState();
}

class _HomeHeaderBodyState extends State<_HomeHeaderBody> {
  final BannerService _bannerService = BannerService();
  List<models.Banner> _banners = [];

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  @override
  void didUpdateWidget(covariant _HomeHeaderBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadBanners();
    }
  }

  Future<void> _loadBanners() async {
    try {
      // Prefer home-specific banners; fall back to wardrobe_list banners
      // (same as Wardrobe screen) if none are configured yet.
      var banners = await _bannerService.getBannersByLocation('home_screen');
      if (banners.isEmpty) {
        banners = await _bannerService.getBannersByLocation('wardrobe_list');
      }
      if (mounted) {
        setState(() {
          _banners = banners;
        });
      }
    } catch (_) {
      // banners are optional
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo-chat.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: widget.brand.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(
                        Icons.checkroom_rounded,
                        size: 30,
                        color: widget.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Advertisement space (same style as login screen) - shown after logo, before features.
          if (_banners.isNotEmpty) ...[
            BannerSliderWidget(
              banners: _banners,
              width: double.infinity,
              height: 100,
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Features',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: accent.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(19),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.2),
                            accent.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accent, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.black.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
