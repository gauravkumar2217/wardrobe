import 'package:flutter/material.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Top';
  String _selectedColor = 'Black';
  String _selectedSeason = 'All Seasons';
  List<String> _selectedTags = [];

  final List<String> _categories = [
    'Top',
    'Bottom',
    'Dress',
    'Outerwear',
    'Shoes',
    'Accessories',
    'Underwear',
  ];

  final List<String> _colors = [
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

  final List<String> _seasons = [
    'Summer',
    'Winter',
    'Spring',
    'Fall',
    'All Seasons',
  ];

  final List<String> _availableTags = [
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

  @override
  void dispose() {
    _itemNameController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _saveItem,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image upload section
              _buildImageSection(),
              const SizedBox(height: 24),

              // Item Name
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.checkroom),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Brand
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  // Size Field
                  Expanded(
                    child: TextFormField(
                      controller: _sizeController,
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Color Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedColor,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.color_lens),
                      ),
                      items: _colors.map((color) {
                        return DropdownMenuItem(
                          value: color,
                          child: Text(color),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedColor = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Season Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSeason,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: _seasons.map((season) {
                  return DropdownMenuItem(
                    value: season,
                    child: Text(season),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSeason = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Tags Section
              _buildTagsSection(),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Add to Wardrobe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _selectImage,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add photo',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedTags.join(', ')}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ],
    );
  }

  void _selectImage() {
    // TODO: Implement image selection logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image selection feature to be implemented'),
      ),
    );
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement save logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to previous screen
      Navigator.pop(context);
    }
  }
}
