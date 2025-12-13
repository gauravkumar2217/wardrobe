import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduler_provider.dart';
import '../../models/schedule.dart';
import 'schedule_edit_screen.dart';

/// Screen showing list of all schedules
class SchedulerListScreen extends StatefulWidget {
  const SchedulerListScreen({super.key});

  @override
  State<SchedulerListScreen> createState() => _SchedulerListScreenState();
}

class _SchedulerListScreenState extends State<SchedulerListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedules();
    });
  }

  Future<void> _loadSchedules() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schedulerProvider = Provider.of<SchedulerProvider>(context, listen: false);

    if (authProvider.user != null) {
      await schedulerProvider.loadSchedules(authProvider.user!.uid);
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule', style: TextStyle(fontSize: 14)),
        content: Text(
          'Are you sure you want to delete "${schedule.title}"?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final schedulerProvider = Provider.of<SchedulerProvider>(context, listen: false);

      final success = await schedulerProvider.deleteSchedule(
        authProvider.user!.uid,
        schedule.id,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedulerProvider = Provider.of<SchedulerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Notifications'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: schedulerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : schedulerProvider.schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No schedules yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first schedule',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedulerProvider.schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedulerProvider.schedules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: schedule.isEnabled
                              ? const Color(0xFF7C3AED)
                              : Colors.grey,
                          child: Icon(
                            schedule.isEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          schedule.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: schedule.isEnabled
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              schedule.scheduleDescription,
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (schedule.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                schedule.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: const Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScheduleEditScreen(schedule: schedule),
                                ),
                              );
                              if (mounted) {
                                await _loadSchedules();
                              }
                            } else if (value == 'delete') {
                              await _deleteSchedule(schedule);
                            }
                          },
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScheduleEditScreen(schedule: schedule),
                            ),
                          );
                          if (mounted) {
                            await _loadSchedules();
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ScheduleEditScreen(),
            ),
          );
          if (mounted) {
            await _loadSchedules();
          }
        },
        backgroundColor: const Color(0xFF7C3AED),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

