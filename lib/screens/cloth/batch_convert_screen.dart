import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../models/cloth.dart';
import '../../services/batch_processing_service.dart';

/// Batch conversion screen for converting old items
class BatchConvertScreen extends StatefulWidget {
  const BatchConvertScreen({super.key});

  @override
  State<BatchConvertScreen> createState() => _BatchConvertScreenState();
}

class _BatchConvertScreenState extends State<BatchConvertScreen> {
  List<Cloth> _itemsToProcess = [];
  bool _isProcessing = false;
  int _currentIndex = 0;
  int _totalItems = 0;
  Cloth? _currentItem;
  int _successCount = 0;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    try {
      await clothProvider.loadClothes(userId: authProvider.user!.uid);
      
      if (mounted) {
        setState(() {
          _itemsToProcess = clothProvider.clothes
              .where((item) => !item.hasProcessedImage || item.processedImageUrl == null)
              .toList();
          _totalItems = _itemsToProcess.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    }
  }

  Future<void> _startProcessing() async {
    if (_itemsToProcess.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to process')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() {
      _isProcessing = true;
      _currentIndex = 0;
      _successCount = 0;
      _failureCount = 0;
    });

    try {
      await BatchProcessingService.processAllItems(
        userId: authProvider.user!.uid,
        items: _itemsToProcess,
        onProgress: (current, total, item) {
          if (mounted) {
            setState(() {
              _currentIndex = current;
              _currentItem = item;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _successCount = _totalItems - _failureCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing completed! Success: $_successCount, Failed: $_failureCount'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload items
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during processing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Batch Convert Items'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: EdgeInsets.zero,
        child: Column(
          children: [
            // Info card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Convert Old Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Items without processed images: ${_itemsToProcess.length}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will process all items to remove backgrounds for use in the changing room feature.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Progress indicator
            if (_isProcessing) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _totalItems > 0 ? _currentIndex / _totalItems : 0,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing $_currentIndex/$_totalItems',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_currentItem != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _currentItem!.clothType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Items list
            Expanded(
              child: _itemsToProcess.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 64, color: Colors.green),
                          const SizedBox(height: 16),
                          const Text(
                            'All items processed!',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All your items are ready for the changing room',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _itemsToProcess.length,
                      itemBuilder: (context, index) {
                        final item = _itemsToProcess[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(item.imageUrl),
                          ),
                          title: Text(item.clothType),
                          subtitle: Text(item.category),
                          trailing: const Icon(
                            Icons.image_not_supported,
                            color: Colors.orange,
                          ),
                        );
                      },
                    ),
            ),

            // Action button
            if (!_isProcessing)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + keyboardInset),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _itemsToProcess.isEmpty ? null : _startProcessing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF043915),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _itemsToProcess.isEmpty
                          ? 'All Items Processed'
                          : 'Start Processing (${_itemsToProcess.length} items)',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
