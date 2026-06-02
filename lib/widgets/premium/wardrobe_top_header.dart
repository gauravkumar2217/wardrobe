import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/wardrobe_tokens.dart';

/// Fixed app shell header: profile + search | floating logo | notifications + settings.
class WardrobeTopHeader extends StatelessWidget {
  /// Height of the header bar area (excluding SafeArea top padding).
  static const double barHeight = 56;

  /// Floating logo size.
  static const double logoSize = _FloatingHeaderLogo.size;

  /// Portion of logo that overflows *outside* the header (below the bottom line).
  /// 40% out, 60% in.
  static const double logoOutFraction = 0.4;

  final VoidCallback onProfilePressed;
  final VoidCallback onNotificationsPressed;
  final VoidCallback onSettingsPressed;

  const WardrobeTopHeader({
    super.key,
    required this.onProfilePressed,
    required this.onNotificationsPressed,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final photoUrl = auth.userProfile?.photoUrl ?? auth.user?.photoURL;
    // Logo sits on the gold bottom line: 60% in header, 40% out.
    const logoBelowLine = logoSize * logoOutFraction;

    return Material(
      color: WardrobeTokens.emeraldBg,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: WardrobeTokens.emeraldBg,
                border: Border(
                  bottom: BorderSide(
                    color: WardrobeTokens.goldPrimary.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                ),
              ),
              child: SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeaderIconButton(
                      onPressed: onProfilePressed,
                      tooltip: 'Profile',
                      child: Hero(
                        tag: 'wardrobe_avatar',
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.18),
                          backgroundImage:
                              photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  color: scheme.primary,
                                  size: 22,
                                )
                              : null,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      onPressed: () {},
                      tooltip: 'Search',
                      icon: Icons.search_rounded,
                    ),
                    const Spacer(),
                    _HeaderIconButton(
                      onPressed: onNotificationsPressed,
                      tooltip: 'Notifications',
                      icon: Icons.notifications_none_rounded,
                    ),
                    _HeaderIconButton(
                      onPressed: onSettingsPressed,
                      tooltip: 'Settings',
                      icon: Icons.settings_rounded,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -logoBelowLine,
              child: const _FloatingHeaderLogo(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeaderLogo extends StatelessWidget {
  static const double size = 68;

  const _FloatingHeaderLogo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WardrobeTokens.emeraldCard,
        border: Border.all(
          color: WardrobeTokens.goldPrimary.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/images/logo-chat.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: scheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.checkroom_rounded,
                size: 34,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final IconData? icon;
  final Widget? child;

  const _HeaderIconButton({
    required this.onPressed,
    required this.tooltip,
    this.icon,
    this.child,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: child ??
          Icon(
            icon,
            size: 24,
          ),
    );
  }
}
