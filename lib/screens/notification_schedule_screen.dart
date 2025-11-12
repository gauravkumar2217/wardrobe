import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_schedule.dart';
import '../services/notification_schedule_service.dart';

class NotificationScheduleScreen extends StatefulWidget {
  const NotificationScheduleScreen({super.key});

  @override
  State<NotificationScheduleScreen> createState() =>
      _NotificationScheduleScreenState();
}

class _NotificationScheduleScreenState
    extends State<NotificationScheduleScreen> {
  List<NotificationSchedule> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await NotificationScheduleService.getSchedules();
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedules: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddScheduleDialog(),
            tooltip: 'Add Schedule',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? _buildEmptyState()
              : _buildSchedulesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notification schedules',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a schedule',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final schedule = _schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  Widget _buildScheduleCard(NotificationSchedule schedule) {
    final timeFormat = DateFormat('h:mm a');
    final timeString = timeFormat.format(
      DateTime(0, 1, 1, schedule.time.hour, schedule.time.minute),
    );

    String repeatText;
    if (schedule.isRepeat) {
      if (schedule.weekdays.length == 7) {
        repeatText = 'Daily';
      } else if (schedule.weekdays.length == 5 &&
          [1, 2, 3, 4, 5].every((day) => schedule.weekdays.contains(day))) {
        repeatText = 'Weekdays';
      } else if (schedule.weekdays.length == 2 &&
          [6, 7].every((day) => schedule.weekdays.contains(day))) {
        repeatText = 'Weekends';
      } else {
        final weekdayNames = schedule.weekdays
            .map((w) => NotificationSchedule.getWeekdayName(w).substring(0, 3))
            .join(', ');
        repeatText = weekdayNames;
      }
    } else {
      repeatText = 'Once';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: schedule.isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
          child: Icon(
            _getOccasionIcon(schedule.occasion),
            color: Colors.white,
          ),
        ),
        title: Text(
          schedule.occasion,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: schedule.isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Time: $timeString'),
            Text('Repeat: $repeatText'),
            if (!schedule.isActive)
              const Text(
                'Inactive',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: schedule.isActive,
              onChanged: (value) => _toggleSchedule(schedule, value),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditScheduleDialog(schedule);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(schedule);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getOccasionIcon(String occasion) {
    switch (occasion.toLowerCase()) {
      case 'office':
        return Icons.business;
      case 'casual':
        return Icons.checkroom;
      case 'party':
        return Icons.celebration;
      case 'formal':
        return Icons.emoji_events;
      case 'wedding':
        return Icons.favorite;
      case 'date':
        return Icons.favorite_border;
      case 'gym':
        return Icons.fitness_center;
      case 'travel':
        return Icons.flight;
      default:
        return Icons.event;
    }
  }

  void _showAddScheduleDialog() {
    _showScheduleDialog();
  }

  void _showEditScheduleDialog(NotificationSchedule schedule) {
    _showScheduleDialog(schedule: schedule);
  }

  void _showScheduleDialog({NotificationSchedule? schedule}) {
    final isEditing = schedule != null;
    String selectedOccasion = schedule?.occasion ?? 'Office';
    TimeOfDay selectedTime = schedule?.time ?? const TimeOfDay(hour: 7, minute: 0);
    bool isRepeat = schedule?.isRepeat ?? false;
    List<int> selectedWeekdays = List.from(schedule?.weekdays ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Schedule' : 'New Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Occasion dropdown
                DropdownButtonFormField<String>(
                  value: selectedOccasion,
                  decoration: const InputDecoration(
                    labelText: 'Occasion',
                    border: OutlineInputBorder(),
                  ),
                  items: NotificationSchedule.getOccasionOptions()
                      .map((occasion) => DropdownMenuItem(
                            value: occasion,
                            child: Text(occasion),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedOccasion = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Time picker
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(
                    selectedTime.format(context),
                    style: const TextStyle(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Repeat toggle
                SwitchListTile(
                  title: const Text('Repeat'),
                  subtitle: Text(isRepeat ? 'Weekly' : 'Once'),
                  value: isRepeat,
                  onChanged: (value) {
                    setDialogState(() {
                      isRepeat = value;
                      if (!value) {
                        selectedWeekdays = [];
                      }
                    });
                  },
                ),

                // Weekday selection (if repeat)
                if (isRepeat) ...[
                  const SizedBox(height: 8),
                  const Text('Select days:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final weekday = index + 1; // 1 = Monday, 7 = Sunday
                      final isSelected = selectedWeekdays.contains(weekday);
                      return FilterChip(
                        label: Text(
                          NotificationSchedule.getWeekdayName(weekday).substring(0, 3),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedWeekdays.add(weekday);
                            } else {
                              selectedWeekdays.remove(weekday);
                            }
                            selectedWeekdays.sort();
                          });
                        },
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (isRepeat && selectedWeekdays.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one day for repeat'),
                    ),
                  );
                  return;
                }

                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                final now = DateTime.now();
                final newSchedule = NotificationSchedule(
                  id: schedule?.id ?? '',
                  occasion: selectedOccasion,
                  time: selectedTime,
                  isRepeat: isRepeat,
                  weekdays: selectedWeekdays,
                  isActive: schedule?.isActive ?? true,
                  createdAt: schedule?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  await NotificationScheduleService.saveSchedule(newSchedule);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Schedule updated successfully'
                            : 'Schedule created successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadSchedules();
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to save schedule: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSchedule(
      NotificationSchedule schedule, bool isActive) async {
    try {
      await NotificationScheduleService.toggleSchedule(schedule.id, isActive);
      _loadSchedules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(NotificationSchedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
          'Are you sure you want to delete the "${schedule.occasion}" schedule?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await NotificationScheduleService.deleteSchedule(schedule.id);
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Schedule deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadSchedules();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete schedule: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

