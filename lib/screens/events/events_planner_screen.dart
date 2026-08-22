import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../models/planned_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/planned_event_service.dart';
import '../../services/tag_list_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../cloth/cloth_detail_screen.dart';

/// Create and manage events with occasion-matched wardrobe suggestions.
class EventsPlannerScreen extends StatefulWidget {
  const EventsPlannerScreen({super.key});

  @override
  State<EventsPlannerScreen> createState() => _EventsPlannerScreenState();
}

class _EventsPlannerScreenState extends State<EventsPlannerScreen> {
  bool _loading = true;
  String? _error;
  List<PlannedEvent> _events = [];
  List<String> _occasions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await TagListService.fetchTagLists();
      final events = await PlannedEventService.getEvents();
      if (!mounted) return;
      setState(() {
        _occasions = TagListService.occasions;
        _events = events;
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

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WardrobeTokens.emeraldBg,
      builder: (_) => _EventFormSheet(
        occasions: _occasions,
        title: 'Schedule event',
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openEvent(PlannedEvent event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          initial: event,
          occasions: _occasions,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WardrobeTokens.emeraldBg,
      appBar: AppBar(
        backgroundColor: WardrobeTokens.emeraldBg,
        title: const Text('Events Planner'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFF043915),
        icon: const Icon(Icons.event_available),
        label: const Text('Add event'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _events.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            _EmptyEventsHint(),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final e = _events[i];
                            return _EventListTile(
                              event: e,
                              onTap: () => _openEvent(e),
                            );
                          },
                        ),
                ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final PlannedEvent? initial;
  final List<String> occasions;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initial,
    this.occasions = const [],
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  PlannedEvent? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _event = widget.initial;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final event = await PlannedEventService.getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load event: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('This removes the event and cancels its reminder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await PlannedEventService.delete(widget.eventId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: WardrobeTokens.emeraldBg,
      appBar: AppBar(
        backgroundColor: WardrobeTokens.emeraldBg,
        title: Text(event?.title ?? 'Event'),
        actions: [
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: _loading && event == null
          ? const Center(child: CircularProgressIndicator())
          : event == null
              ? const Center(child: Text('Event not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WardrobeTokens.outlineGold),
                        color: const Color(0xFF06231E),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(Icons.celebration_outlined, event.occasionTag),
                          _InfoRow(Icons.schedule, event.dateLabel),
                          if (event.location != null && event.location!.isNotEmpty)
                            _InfoRow(Icons.place_outlined, event.location!),
                          _InfoRow(
                            Icons.notifications_active_outlined,
                            'Reminder ${event.reminderHoursBefore}h before',
                          ),
                          if (event.notes != null && event.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(event.notes!.trim()),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Suggested outfits',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matched to your wardrobe ${event.occasionTag} tags',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (event.suggestions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: WardrobeTokens.outlineGold),
                        ),
                        child: const Text(
                          'No matching clothes yet. Add items with the same occasion/festival tag to your wardrobe.',
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: event.suggestions.length,
                        itemBuilder: (context, i) {
                          final s = event.suggestions[i];
                          return _SuggestionTile(suggestion: s);
                        },
                      ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final EventClothSuggestion suggestion;
  const _SuggestionTile({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final auth = context.read<AuthProvider>();
        final uid = auth.user?.uid;
        final wardrobeId = suggestion.wardrobeId;
        if (uid == null || wardrobeId == null || wardrobeId.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClothDetailScreen(
              clothId: suggestion.id,
              ownerId: uid,
              wardrobeId: wardrobeId,
              isOwner: true,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WardrobeTokens.outlineGold),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: CachedNetworkImage(
                  imageUrl: suggestion.displayImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.checkroom),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.clothType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    suggestion.matchReason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final PlannedEvent event;
  final VoidCallback onTap;

  const _EventListTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = event.suggestions.isNotEmpty
        ? event.suggestions.first.displayImageUrl
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WardrobeTokens.outlineGold),
            color: const Color(0xFF06231E),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: preview != null && preview.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: preview,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _icon(scheme),
                        )
                      : _icon(scheme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      '${event.occasionTag} · ${event.dateLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                    if (event.suggestions.isNotEmpty)
                      Text(
                        '${event.suggestions.length} outfit suggestions',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
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
    );
  }

  Widget _icon(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.14),
      child: Icon(Icons.event, color: scheme.primary),
    );
  }
}

class _EmptyEventsHint extends StatelessWidget {
  const _EmptyEventsHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded,
              size: 48, color: scheme.primary.withValues(alpha: 0.85)),
          const SizedBox(height: 12),
          Text(
            'Plan your next event',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a wedding, festival, or party — we’ll suggest clothes from your wardrobe that match the occasion tags.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  final List<String> occasions;
  final String title;

  const _EventFormSheet({
    required this.occasions,
    required this.title,
  });

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String? _occasion;
  DateTime _eventAt = DateTime.now().add(const Duration(days: 1));
  int _reminderHours = 24;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _eventAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _occasion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and occasion are required')),
      );
      return;
    }
    if (_eventAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event must be in the future')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await PlannedEventService.create(
        title: title,
        occasionTag: _occasion!,
        eventAt: _eventAt,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        reminderHoursBefore: _reminderHours,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Event name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _occasion,
              decoration: const InputDecoration(
                labelText: 'Occasion / festival tag',
              ),
              items: widget.occasions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _occasion = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date & time'),
              subtitle: Text(
                '${_eventAt.day}/${_eventAt.month}/${_eventAt.year} '
                '${TimeOfDay.fromDateTime(_eventAt).format(context)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _reminderHours,
              decoration: const InputDecoration(labelText: 'Reminder before'),
              items: const [
                DropdownMenuItem(value: 2, child: Text('2 hours before')),
                DropdownMenuItem(value: 6, child: Text('6 hours before')),
                DropdownMenuItem(value: 12, child: Text('12 hours before')),
                DropdownMenuItem(value: 24, child: Text('1 day before')),
                DropdownMenuItem(value: 48, child: Text('2 days before')),
              ],
              onChanged: (v) => setState(() => _reminderHours = v ?? 24),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF043915),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save event'),
            ),
          ],
        ),
      ),
    );
  }
}
