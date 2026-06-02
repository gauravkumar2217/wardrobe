import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cloth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduler_provider.dart';
import '../../services/cloth_service.dart';
import '../../services/outfit_suggestion_service.dart';
import '../../models/schedule.dart';
import '../cloth/cloth_detail_screen.dart';

class DailySuggestionScreen extends StatefulWidget {
  const DailySuggestionScreen({super.key});

  @override
  State<DailySuggestionScreen> createState() => _DailySuggestionScreenState();
}

class _DailySuggestionScreenState extends State<DailySuggestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Cloth> _allClothes = [];
  List<Cloth> _suggestedClothes = [];
  String? _title;
  String? _description;
  Map<String, dynamic> _metadata = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceNew = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user == null) {
        setState(() {
          _errorMessage = 'Please login to view daily suggestions';
          _isLoading = false;
        });
        return;
      }

      final userId = auth.user!.uid;
      final clothes = await ClothService.getAllUserClothes(userId);

      final suggestion = await OutfitSuggestionService.getOrCreateDailySuggestion(
        userId: userId,
        availableClothes: clothes,
        forceNew: forceNew,
      );

      if (suggestion == null) {
        setState(() {
          _allClothes = clothes;
          _suggestedClothes = [];
          _title = null;
          _description = null;
          _metadata = {};
          _errorMessage =
              clothes.isEmpty ? 'No items found. Add clothes to get suggestions.' : 'Not enough items to build a suggestion.';
          _isLoading = false;
        });
        return;
      }

      final byId = <String, Cloth>{for (final c in clothes) c.id: c};
      final suggested = suggestion.clothIds
          .map((id) => byId[id])
          .whereType<Cloth>()
          .toList();

      setState(() {
        _allClothes = clothes;
        _suggestedClothes = suggested;
        _title = suggestion.title;
        _description = suggestion.description;
        _metadata = suggestion.metadata;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load daily suggestion: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _scheduleDailyReminder() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;

    final scheduler = Provider.of<SchedulerProvider>(context, listen: false);
    final now = DateTime.now();

    final schedule = Schedule(
      id: 'daily_suggestion',
      userId: auth.user!.uid,
      title: 'Daily suggestion',
      description: 'Your daily outfit suggestion is ready. Tap to view.',
      hour: picked.hour,
      minute: picked.minute,
      daysOfWeek: const [0, 1, 2, 3, 4, 5, 6],
      isEnabled: true,
      filterSettings: const {
        'purpose': 'daily_suggestion',
      },
      createdAt: now,
      updatedAt: now,
    );

    // Upsert: if schedule exists, update; otherwise add.
    final existing = scheduler.getScheduleById(schedule.id);
    final ok = existing == null
        ? await scheduler.addSchedule(auth.user!.uid, schedule)
        : await scheduler.updateSchedule(auth.user!.uid, schedule);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Daily reminder scheduled' : 'Failed to schedule reminder'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily suggestion'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(forceNew: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _scheduleDailyReminder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF043915),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Schedule daily reminder'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(forceNew: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb, color: Color(0xFF043915)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _title ?? 'Daily suggestion',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((_description ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _description!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if ((_metadata['anchorCategory'] as String?)?.isNotEmpty == true)
                                    _Chip(text: 'Category: ${_metadata['anchorCategory']}'),
                                  if ((_metadata['anchorSeason'] as String?)?.isNotEmpty == true)
                                    _Chip(text: 'Season: ${_metadata['anchorSeason']}'),
                                  if ((_metadata['anchorOccasions'] is List) &&
                                      (_metadata['anchorOccasions'] as List).isNotEmpty)
                                    _Chip(text: 'Occasion: ${(List.from(_metadata['anchorOccasions']).first)}'),
                                  if ((_metadata['anchorColors'] is List) &&
                                      (_metadata['anchorColors'] as List).isNotEmpty)
                                    _Chip(text: 'Color: ${(List.from(_metadata['anchorColors']).first)}'),
                                  if ((_metadata['anchorDaysSinceWorn'] is int) &&
                                      (_metadata['anchorDaysSinceWorn'] as int) < 100000)
                                    _Chip(text: 'Not worn: ${_metadata['anchorDaysSinceWorn']} days'),
                                  if ((_metadata['anchorDaysSinceWorn'] is int) &&
                                      (_metadata['anchorDaysSinceWorn'] as int) >= 100000)
                                    const _Chip(text: 'Never worn'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _scheduleDailyReminder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF043915),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.alarm),
                                label: const Text('Schedule daily reminder'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Suggested items',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (_suggestedClothes.isEmpty)
                        Text(
                          'No items in this suggestion.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _suggestedClothes.length,
                          itemBuilder: (context, i) {
                            final cloth = _suggestedClothes[i];
                            return GestureDetector(
                              onTap: () async {
                                final auth = Provider.of<AuthProvider>(context, listen: false);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClothDetailScreen(
                                      cloth: cloth,
                                      isOwner: auth.user?.uid == cloth.ownerId,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 1,
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Image.network(
                                        cloth.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cloth.clothType,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            cloth.itemKind,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _load(forceNew: true),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Generate another suggestion'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tip: The suggestion prioritizes items you haven’t worn for a long time and tries to match by season, occasion, category, and colors (including accessories).',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      // keep for potential future use without linting warnings
                      if (_allClothes.isEmpty) const SizedBox.shrink(),
                    ],
                  ),
                ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF043915).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF043915).withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

