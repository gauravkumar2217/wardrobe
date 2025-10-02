import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // TODO: Implement navigation based on selected index
    switch (index) {
      case 0:
        // Wardrobe Tab
        break;
      case 1:
        // Weather/Outfit Suggestions Tab
        break;
      case 2:
        // Calendar Tab
        break;
      case 3:
        // Settings Tab
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wordrope'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // TODO: Navigate to profile screen
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          WardrobeTab(),
          WeatherTab(),
          CalendarTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom),
            label: 'Wardrobe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny),
            label: 'Weather',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class WardrobeTab extends StatelessWidget {
  const WardrobeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Wardrobe',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to add item screen
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(4, (index) {
                return Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checkroom,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clothing Item ${index + 1}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherTab extends StatelessWidget {
  const WeatherTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wb_sunny,
            size: 80,
            color: Colors.amber,
          ),
          SizedBox(height: 16),
          Text(
            'Weather-Based Outfit Suggestions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Feature coming soon...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            'Outfit Calendar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Feature coming soon...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Profile'),
              subtitle: Text('Manage your account'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.palette),
              title: Text('Theme'),
              subtitle: Text('Customize app appearance'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              subtitle: Text('Manage notification preferences'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.help),
              title: Text('Help & Support'),
              subtitle: Text('Get help and support'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}
