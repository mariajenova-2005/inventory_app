import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models/item.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'utils/sync_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6C63FF),
          elevation: 4,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const InventoryApp(),
    );
  }
}

class InventoryApp extends StatefulWidget {
  const InventoryApp({super.key});

  @override
  State<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends State<InventoryApp> {
  final Uuid _uuid = Uuid();
  final SyncQueue _syncQueue = SyncQueue();
  
  List<Item> _items = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // Load items from local and cloud
  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    
    // Load from local storage
    final localItems = await StorageService.loadItems();
    
    // Always load from mock API (works offline too)
    try {
      final cloudItems = await ApiService.fetchItems();
      
      // Merge cloud items with local items
      final Map<String, Item> mergedItems = {};
      
      // Add cloud items first (they have priority)
      for (var cloudItem in cloudItems) {
        mergedItems[cloudItem.id] = cloudItem;
      }
      
      // Add local items (won't overwrite cloud items with same ID)
      for (var localItem in localItems) {
        if (!mergedItems.containsKey(localItem.id)) {
          mergedItems[localItem.id] = localItem;
        }
      }
      
      _items = mergedItems.values.toList();
      await StorageService.saveItems(_items);
      
    } catch (e) {
      // If something goes wrong, use local items
      _items = localItems;
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveItems() async {
    await StorageService.saveItems(_items);
  }

  // CREATE Item
  Future<void> _createItem(Item item) async {
    setState(() => _isLoading = true);
    
    // Generate local ID
    final localItem = item.copyWith(id: 'LOCAL-${_uuid.v4()}');
    
    // Add to local list
    _items.add(localItem);
    await _saveItems();
    
    // Add to sync queue (will sync to mock API)
    await _syncQueue.addOperation(type: 'create', item: localItem);
    
    setState(() => _isLoading = false);
    
    _showSuccessMessage('Item added successfully');
  }

  // UPDATE Item
  Future<void> _updateItem(String itemId, Item updatedItem) async {
    setState(() => _isLoading = true);
    
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    
    // Update local item
    final oldItem = _items[index];
    final newItem = updatedItem.copyWith(
      id: oldItem.id, 
      isSynced: oldItem.isSynced
    );
    _items[index] = newItem;
    await _saveItems();
    
    // Add to sync queue if item was previously synced
    if (oldItem.isSynced) {
      await _syncQueue.addOperation(type: 'update', item: newItem);
    }
    
    setState(() => _isLoading = false);
    
    _showSuccessMessage('Item updated successfully');
  }

  // DELETE Item
  Future<void> _deleteItem(String itemId) async {
    final item = _items.firstWhere((item) => item.id == itemId);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      // Remove from local list
      _items.removeWhere((item) => item.id == itemId);
      await _saveItems();
      
      // Add to sync queue (only if it was synced before)
      if (item.isSynced) {
        await _syncQueue.addOperation(type: 'delete', item: item);
      }
      
      setState(() => _isLoading = false);
      
      _showSuccessMessage('Item deleted');
    }
  }

  // SYNC with mock API
  Future<void> _syncWithApi() async {
    if (_syncQueue.isSyncing) return;
    
    setState(() => _isLoading = true);
    
    final result = await _syncQueue.syncAll();
    
    // Reload items to get updated sync status
    await _loadItems();
    
    setState(() => _isLoading = false);
    
    // Show message only if sync was successful
    if (result['success'] && result['synced'] > 0) {
      _showSuccessMessage('${result['synced']} items synced with cloud');
    }
  }

  // RELOAD cloud data
  Future<void> _reloadCloudData() async {
    setState(() => _isLoading = true);
    
    try {
      final cloudItems = await ApiService.fetchItems();
      
      // Add cloud items that don't already exist
      int newItems = 0;
      for (final cloudItem in cloudItems) {
        if (!_items.any((item) => item.id == cloudItem.id)) {
          _items.add(cloudItem);
          newItems++;
        }
      }
      
      await _saveItems();
      setState(() {});
      
      if (newItems > 0) {
        _showSuccessMessage('Loaded $newItems items from cloud');
      } else {
        _showSuccessMessage('Cloud data is up to date');
      }
      
    } catch (e) {
      _showSuccessMessage('Error loading cloud data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Item> _getFilteredItems() {
    if (_searchQuery.isEmpty) return _items;
    
    return _items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             item.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _openItemForm({Item? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final priceController = TextEditingController(text: item?.price.toStringAsFixed(2) ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter item name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter description',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (₹) *',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '* Required fields',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                _showSuccessMessage('Please enter item name');
                return;
              }
              if (descController.text.isEmpty) {
                _showSuccessMessage('Please enter description');
                return;
              }
              if (priceController.text.isEmpty) {
                _showSuccessMessage('Please enter price');
                return;
              }

              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                _showSuccessMessage('Please enter valid price');
                return;
              }

              final newItem = Item(
                id: item?.id ?? '',
                name: nameController.text.trim(),
                description: descController.text.trim(),
                price: price,
              );

              if (item == null) {
                _createItem(newItem);
              } else {
                _updateItem(item.id, newItem);
              }

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: Text(item == null ? 'Add Item' : 'Update Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final totalValue = _items.fold<double>(0, (sum, item) => sum + item.price);
    final cloudCount = _items.where((item) => item.isSynced || item.id.startsWith('CLOUD-')).length;
    final localCount = _items.length - cloudCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9A94FF)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Cloud Connected',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_syncQueue.pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sync, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${_syncQueue.pendingCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Title and Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Manager',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cloud + Local Storage',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_items.length} items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search items...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6C63FF)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _reloadCloudData,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Reload Cloud Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _syncQueue.pendingCount > 0 ? _syncWithApi : null,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text('Sync (${_syncQueue.pendingCount})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _syncQueue.pendingCount > 0 ? Colors.green : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      value: _items.length.toString(),
                      label: 'Total Items',
                      icon: Icons.inventory,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      value: cloudCount.toString(),
                      label: 'Cloud Items',
                      icon: Icons.cloud_done,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      value: localCount.toString(),
                      label: 'Local Items',
                      icon: Icons.storage,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Items List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading data...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No items yet' : 'No matching items',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap "Reload Cloud Data" for sample items',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchQuery.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton(
                                    onPressed: () => _openItemForm(),
                                    child: const Text('Add First Item'),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isCloudItem = item.id.startsWith('CLOUD-') || item.isSynced;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: isCloudItem
                                      ? Colors.green.shade100 
                                      : Colors.orange.shade100,
                                  width: 1.5,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isCloudItem
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isCloudItem ? Icons.cloud_done : Icons.storage,
                                    color: isCloudItem ? Colors.green : Colors.orange,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '₹${item.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCloudItem
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isCloudItem ? 'Cloud' : 'Local',
                                            style: TextStyle(
                                              color: isCloudItem
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (item.id.startsWith('CLOUD-')) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Cloud',
                                              style: TextStyle(
                                                color: Colors.purple,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _openItemForm(item: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteItem(item.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemForm(),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}