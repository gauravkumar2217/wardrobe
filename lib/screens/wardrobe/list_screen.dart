import 'package:flutter/material.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _isGridView = true;
  String _selectedCategory = 'All';
  String _selectedColor = 'All';
  String _selectedTag = 'All';
  String _sortBy = 'Newest';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Top',
    'Bottom',
    'Dress',
    'Outerwear',
    'Shoes',
    'Accessories',
    'Underwear',
  ];

  final List<String> _colors = [
    'All',
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Brown',
    'Gray',
    'Pink',
    'Purple',
    'Orange',
    'Beige',
    'Navy',
    'Maroon',
  ];

  final List<String> _tags = [
    'All',
    'Casual',
    'Formal',
    'Party',
    'Work',
    'Sport',
    'Comfortable',
    'Trendy',
    'Vintage',
    'Chic',
    'Simple',
  ];

  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Alphabetical',
    'Price',
    'Color',
    'Brand',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.view_module),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  // TODO: Implement search filtering
                });
              },
            ),
          ),

          // Filter Row
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('Category', _selectedCategory, _categories),
                const SizedBox(width: 8),
                _buildFilterChip('Color', _selectedColor, _colors),
                const SizedBox(width: 8),
                _buildFilterChip('Tag', _selectedTag, _tags),
                const SizedBox(width: 8),
                _buildFilterChip('Sort', _sortBy, _sortOptions),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items List
          Expanded(
            child: _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add item screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navigate to Add Item Screen'),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options) {
    return FilterChip(
      label: Text('$label: $value'),
      selected: value != 'All',
      onSelected: (selected) {
        _showFilterDialog(label, value, options);
      },
    );
  }

  void _showFilterDialog(String label, String value, List<String> options) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: value,
                onChanged: (newValue) {
                  setState(() {
                    switch (label) {
                      case 'Category':
                        _selectedCategory = newValue!;
                        break;
                      case 'Color':
                        _selectedColor = newValue!;
                        break;
                      case 'Tag':
                        _selectedTag = newValue!;
                        break;
                      case 'Sort':
                        _sortBy = newValue!;
                        break;
                    }
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: 8, // TODO: Replace with actual count
      itemBuilder: (context, index) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: const Icon(
                    Icons.checkroom,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category • Color',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8, // TODO: Replace with actual count
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.checkroom,
                color: Colors.grey,
              ),
            ),
            title: Text('Item ${index + 1}'),
            subtitle: Text('Category • Brand • Size'),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    // TODO: Navigate to edit item screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit item')),
                    );
                    break;
                  case 'delete':
                    _showDeleteConfirmation(index);
                    break;
                }
              },
            ),
            onTap: () {
              // TODO: Navigate to item detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('View details for Item ${index + 1}')),
              );
            },
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement delete logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item deleted'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}