import 'package:flutter/material.dart';
import '../models/wardrobe.dart';
import '../theme/wardrobe_tokens.dart';
import 'premium/premium_card.dart';

/// Wardrobe card widget with improved UI/UX
class WardrobeCard extends StatefulWidget {
  final Wardrobe wardrobe;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WardrobeCard({
    super.key,
    required this.wardrobe,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<WardrobeCard> createState() => _WardrobeCardState();
}

class _WardrobeCardState extends State<WardrobeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: PremiumCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.wardrobe.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.72),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.wardrobe.location,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          scheme.onSurface.withValues(alpha: 0.72),
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CountPill(count: widget.wardrobe.totalItems),
                ],
              ),
              if (widget.onEdit != null || widget.onDelete != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onEdit != null)
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: scheme.primary,
                        onPressed: widget.onEdit!,
                      ),
                    if (widget.onEdit != null && widget.onDelete != null)
                      const SizedBox(width: 12),
                    if (widget.onDelete != null)
                      _ActionButton(
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        color: Colors.redAccent,
                        onPressed: widget.onDelete!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: WardrobeTokens.outlineGold),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checkroom_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface.withValues(alpha: 0.92),
                ),
          ),
        ],
      ),
    );
  }
}

/// Custom action button with improved styling
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (color == scheme.primary
                      ? WardrobeTokens.outlineGold
                      : color.withValues(alpha: 0.35))
                  .withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
