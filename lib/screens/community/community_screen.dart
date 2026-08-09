import 'package:flutter/material.dart';

import '../../theme/wardrobe_tokens.dart';
import '../chat/chat_list_screen.dart';
import '../friends/friends_list_screen.dart';
import 'style_feed_tab.dart';

/// Community hub: Style posts · Friends · Chats.
///
/// Style Feed = look photos users post (not wardrobe inventory).
/// Wardrobe items are created by scanning photos (including from Style posts).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: WardrobeTokens.emeraldBg,
          child: TabBar(
            controller: _tabController,
            indicatorColor: scheme.primary,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.7),
            tabs: const [
              Tab(text: 'Style'),
              Tab(text: 'Friends'),
              Tab(text: 'Chats'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              StyleFeedTab(),
              FriendsListScreen(embedded: true),
              ChatListScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
