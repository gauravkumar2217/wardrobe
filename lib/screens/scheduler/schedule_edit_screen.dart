import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduler_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/schedule.dart';
import '../../models/wardrobe.dart';

/// Screen for creating/editing a schedule
class ScheduleEditScreen extends StatefulWidget {
  final Schedule? schedule;

  const ScheduleEditScreen({super.key, this.schedule});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Default: Weekdays
  bool _isEnabled = true;

  // Filter settings
  Set<String> _selectedTypes = {};
  Set<String> _selectedOccasions = {};
  Set<String> _selectedSeasons = {};
  Set<String> _selectedColors = {};
  String? _selectedWardrobeId;

  // Available options
  Map<String, int> _typeCounts = {};
  Map<String, int> _occasionCounts = {};
  Map<String, int> _seasonCounts = {};
  Map<String, int> _colorCounts = {};
  List<Wardrobe> _wardrobes = [];
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _loadScheduleData(widget.schedule!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadScheduleData(Schedule schedule) {
    _titleController.text = schedule.title;
    _descriptionController.text = schedule.description ?? '';
    _selectedTime = TimeOfDay(hour: schedule.hour, minute: schedule.minute);
    _selectedDays = schedule.daysOfWeek.toSet();
    _isEnabled = schedule.isEnabled;

    final filters = schedule.filterSettings;
    if (filters['types'] != null) {
      _selectedTypes = List<String>.from(filters['types']).toSet();
    }
    if (filters['occasions'] != null) {
      _selectedOccasions = List<String>.from(filters['occasions']).toSet();
    }
    if (filters['seasons'] != null) {
      _selectedSeasons = List<String>.from(filters['seasons']).toSet();
    }
    if (filters['colors'] != null) {
      _selectedColors = List<String>.from(filters['colors']).toSet();
    }
    if (filters['wardrobeId'] != null) {
      _selectedWardrobeId = filters['wardrobeId'] as String;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clothProvider = Provider.of<ClothProvider>(context, listen: false);
      final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);

      if (authProvider.user != null) {
        // Load clothes to calculate statistics
        await clothProvider.loadClothes(userId: authProvider.user!.uid);
        final clothes = clothProvider.clothes;

        // Calculate counts
        final typeCounts = <String, int>{};
        final occasionCounts = <String, int>{};
        final seasonCounts = <String, int>{};
        final colorCounts = <String, int>{};

        for (var cloth in clothes) {
          typeCounts[cloth.clothType] = (typeCounts[cloth.clothType] ?? 0) + 1;
          for (var occasion in cloth.occasions) {
            occasionCounts[occasion] = (occasionCounts[occasion] ?? 0) + 1;
          }
          seasonCounts[cloth.season] = (seasonCounts[cloth.season] ?? 0) + 1;
          for (var color in cloth.colorTags.colors) {
            colorCounts[color] = (colorCounts[color] ?? 0) + 1;
          }
        }

        // Load wardrobes
        await wardrobeProvider.loadWardrobes(authProvider.user!.uid);

        setState(() {
          _typeCounts = typeCounts;
          _occasionCounts = occasionCounts;
          _seasonCounts = seasonCounts;
          _colorCounts = colorCounts;
          _wardrobes = wardrobeProvider.wardrobes;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectDays() async {
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Days'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (index) {
                return CheckboxListTile(
                  title: Text(dayNames[index]),
                  value: _selectedDays.contains(index),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDays.add(index);
                      } else {
                        _selectedDays.remove(index);
                      }
                    });
                  },
                );
              }),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedDays = selected;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final schedulerProvider = Provider.of<SchedulerProvider>(context, listen: false);

      if (authProvider.user == null) {
        throw Exception('User not logged in');
      }

      final now = DateTime.now();
      final schedule = Schedule(
        id: widget.schedule?.id ?? const Uuid().v4(),
        userId: authProvider.user!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        daysOfWeek: _selectedDays.toList()..sort(),
        isEnabled: _isEnabled,
        filterSettings: {
          'types': _selectedTypes.toList(),
          'occasions': _selectedOccasions.toList(),
          'seasons': _selectedSeasons.toList(),
          'colors': _selectedColors.toList(),
          if (_selectedWardrobeId != null) 'wardrobeId': _selectedWardrobeId,
        },
        createdAt: widget.schedule?.createdAt ?? now,
        updatedAt: now,
      );

      final success = widget.schedule == null
          ? await schedulerProvider.addSchedule(authProvider.user!.uid, schedule)
          : await schedulerProvider.updateSchedule(authProvider.user!.uid, schedule);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.schedule == null
                    ? 'Schedule created'
                    : 'Schedule updated',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save schedule')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? 'New Schedule' : 'Edit Schedule'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'e.g., Office Clothes Reminder',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add a note about this schedule',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Time
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF7C3AED)),
                      title: const Text('Time'),
                      subtitle: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectTime,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Days
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF7C3AED)),
                      title: const Text('Days'),
                      subtitle: Text(
                        _getDaysText(),
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectDays,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enabled toggle
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.notifications_active, color: Color(0xFF7C3AED)),
                      title: const Text('Enable Schedule'),
                      subtitle: const Text('Turn on/off this schedule'),
                      value: _isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isEnabled = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Filter Settings Section
                  const Text(
                    'Filter Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select filters to apply when this notification triggers',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wardrobe filter
                  if (_wardrobes.isNotEmpty) ...[
                    _buildWardrobeFilter(),
                    const SizedBox(height: 16),
                  ],

                  // Type filter
                  if (_typeCounts.isNotEmpty) ...[
                    _buildFilterChips(
                      title: 'Types',
                      options: _typeCounts.keys.toList(),
                      selected: _selectedTypes,
                      onToggle: (value) {
                        setState(() {
                          if (_selectedTypes.contains(value)) {
                            _selectedTypes.remove(value);
                          } else {
                            _selectedTypes.add(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Occasion filter
                  if (_occasionCounts.isNotEmpty) ...[
                    _buildFilterChips(
                      title: 'Occasions',
                      options: _occasionCounts.keys.toList(),
                      selected: _selectedOccasions,
                      onToggle: (value) {
                        setState(() {
                          if (_selectedOccasions.contains(value)) {
                            _selectedOccasions.remove(value);
                          } else {
                            _selectedOccasions.add(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Season filter
                  if (_seasonCounts.isNotEmpty) ...[
                    _buildFilterChips(
                      title: 'Seasons',
                      options: _seasonCounts.keys.toList(),
                      selected: _selectedSeasons,
                      onToggle: (value) {
                        setState(() {
                          if (_selectedSeasons.contains(value)) {
                            _selectedSeasons.remove(value);
                          } else {
                            _selectedSeasons.add(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Color filter
                  if (_colorCounts.isNotEmpty) ...[
                    _buildFilterChips(
                      title: 'Colors',
                      options: _colorCounts.keys.toList(),
                      selected: _selectedColors,
                      onToggle: (value) {
                        setState(() {
                          if (_selectedColors.contains(value)) {
                            _selectedColors.remove(value);
                          } else {
                            _selectedColors.add(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Schedule',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getDaysText() {
    if (_selectedDays.isEmpty) {
      return 'No days selected';
    }
    if (_selectedDays.length == 7) {
      return 'Daily';
    }
    if (_selectedDays.length == 5 && _selectedDays.containsAll([1, 2, 3, 4, 5])) {
      return 'Weekdays';
    }
    if (_selectedDays.length == 2 && _selectedDays.containsAll([0, 6])) {
      return 'Weekends';
    }
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sortedDays = _selectedDays.toList()..sort();
    return sortedDays.map((d) => dayNames[d]).join(', ');
  }

  Widget _buildWardrobeFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wardrobe',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._wardrobes.map((wardrobe) {
              final isSelected = _selectedWardrobeId == wardrobe.id;
              return RadioListTile<String>(
                title: Text(wardrobe.name),
                subtitle: wardrobe.location.isNotEmpty
                    ? Text(wardrobe.location)
                    : null,
                value: wardrobe.id,
                groupValue: _selectedWardrobeId,
                onChanged: (value) {
                  setState(() {
                    _selectedWardrobeId = value;
                  });
                },
                secondary: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED))
                    : null,
              );
            }),
            RadioListTile<String?>(
              title: const Text('All Wardrobes'),
              value: null,
              groupValue: _selectedWardrobeId,
              onChanged: (value) {
                setState(() {
                  _selectedWardrobeId = null;
                });
              },
              secondary: _selectedWardrobeId == null
                  ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips({
    required String title,
    required List<String> options,
    required Set<String> selected,
    required Function(String) onToggle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (value) => onToggle(option),
                  selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF7C3AED),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

