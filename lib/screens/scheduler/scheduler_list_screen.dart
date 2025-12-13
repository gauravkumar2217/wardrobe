import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduler_provider.dart';
import '../../models/schedule.dart';
import '../../services/schedule_notification_worker.dart';
import '../../services/local_notification_service.dart';
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

  Future<void> _testScheduleNotification(Schedule schedule) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🧪 TEST NOTIFICATION BUTTON CLICKED');
    print('═══════════════════════════════════════════════════════');
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.user == null) {
      print('❌ No user logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to test notifications')),
        );
      }
      return;
    }
    
    print('✅ User ID: ${authProvider.user!.uid}');
    print('📋 Testing schedule: ${schedule.title}');
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Testing notification...',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    try {
      print('📞 Calling ScheduleNotificationWorker.testSendScheduleNotification()...');
      final result = await ScheduleNotificationWorker.testSendScheduleNotification(
        schedule,
        authProvider.user!.uid,
      );
      
      print('✅ Test completed. Result: $result');
      
      if (mounted) {
        final success = result['success'] as bool;
        final message = result['message'] as String;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: success ? Colors.green : Colors.orange,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Notification Result', style: TextStyle(fontSize: 14)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Check the terminal for detailed logs.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        if (!success) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '⚠️ If notification did not appear, check:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Notification permissions are enabled\n'
                            '2. App notifications are not blocked\n'
                            '3. Do Not Disturb mode is off',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncAndCheckSchedules() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔄 SYNC BUTTON CLICKED - Starting manual check...');
    print('═══════════════════════════════════════════════════════');
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.user == null) {
      print('❌ No user logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to sync schedules')),
        );
      }
      return;
    }
    
    print('✅ User ID: ${authProvider.user!.uid}');

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Checking schedules from last 15 minutes...',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      print('📞 Calling ScheduleNotificationWorker.manualCheckLast15Minutes()...');
      // Manually trigger the worker to check last 15 minutes
      final result = await ScheduleNotificationWorker.manualCheckLast15Minutes(
        authProvider.user!.uid,
      );
      print('✅ Worker returned result: $result');

      if (mounted) {
        final message = result['message'] as String;
        final schedulesFound = result['schedulesFound'] as int;
        final notificationsSent = result['notificationsSent'] as int;

        // Show warning if schedules found but no notifications sent
        final hasIssue = schedulesFound > 0 && notificationsSent == 0;
        final displayMessage = hasIssue
            ? '$message\n⚠️ Check notification permissions in device settings!'
            : message;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage, style: const TextStyle(fontSize: 13)),
            duration: const Duration(seconds: 5),
            backgroundColor: hasIssue ? Colors.orange : null,
            action: schedulesFound > 0
                ? SnackBarAction(
                    label: 'Details',
                    textColor: Colors.white,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sync Results', style: TextStyle(fontSize: 14)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Found $schedulesFound schedule(s) that should have triggered.',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sent $notificationsSent notification(s).',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (hasIssue) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  '⚠️ If no notification appeared, please check:',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '1. Notification permissions are enabled\n'
                                  '2. App notifications are not blocked\n'
                                  '3. Do Not Disturb mode is off',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking schedules: $e'),
            backgroundColor: Colors.red,
          ),
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
        actions: [
          // Test notification button (for debugging)
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test Notification',
            onPressed: () async {
              print('');
              print('═══════════════════════════════════════════════════════');
              print('🔔 BELL ICON (TEST NOTIFICATION) BUTTON CLICKED');
              print('═══════════════════════════════════════════════════════');
              print('⏰ Time: ${DateTime.now().toIso8601String()}');
              print('');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sending test notification...',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              
              print('📞 Calling LocalNotificationService.sendTestNotification()...');
              final sent = await LocalNotificationService.sendTestNotification();
              
              print('');
              print('═══════════════════════════════════════════════════════');
              print('📊 TEST NOTIFICATION RESULT:');
              print('   Success: $sent');
              print('═══════════════════════════════════════════════════════');
              print('');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      sent
                          ? '✅ Test notification sent! Check your notifications.'
                          : '❌ Failed to send. Check terminal logs and permissions.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    duration: const Duration(seconds: 4),
                    backgroundColor: sent ? Colors.green : Colors.orange,
                    action: SnackBarAction(
                      label: 'Details',
                      textColor: Colors.white,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Test Notification', style: TextStyle(fontSize: 14)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sent
                                      ? '✅ Notification sent successfully!'
                                      : '❌ Failed to send notification.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Check the terminal for detailed logs.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                                if (!sent) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    '⚠️ Troubleshooting:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '1. Go to Settings → Apps → Wardrobe → Notifications\n'
                                    '2. Enable "Allow notifications"\n'
                                    '3. Ensure "Scheduled Notifications" channel is enabled\n'
                                    '4. Disable "Do Not Disturb" mode',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync & Check Last 15 Minutes',
            onPressed: _syncAndCheckSchedules,
          ),
        ],
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
                              value: 'test',
                              child: const Row(
                                children: [
                                  Icon(Icons.send, size: 18, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 8),
                                  Text('Test Notification', style: TextStyle(fontSize: 13, color: Color(0xFF7C3AED))),
                                ],
                              ),
                            ),
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
                            if (value == 'test') {
                              await _testScheduleNotification(schedule);
                            } else if (value == 'edit') {
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

