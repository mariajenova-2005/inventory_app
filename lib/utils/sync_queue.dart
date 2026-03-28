import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class SyncQueue {
  static final Uuid _uuid = Uuid();
  List<PendingOperation> _pendingOperations = [];
  bool _isSyncing = false;

  SyncQueue() {
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    _pendingOperations = await StorageService.loadPendingOperations();
  }

  Future<void> _saveOperations() async {
    await StorageService.savePendingOperations(_pendingOperations);
  }

  // Add operation to queue
  Future<void> addOperation({
    required String type,
    required Item? item,
  }) async {
    final operation = PendingOperation(
      id: _uuid.v4(),
      type: type,
      item: item,
    );
    
    _pendingOperations.add(operation);
    await _saveOperations();
  }

  // Process all pending operations
  Future<Map<String, dynamic>> syncAll() async {
    if (_isSyncing) {
      return {'success': false, 'message': ''};
    }

    _isSyncing = true;

    int successCount = 0;
    final List<String> processedIds = [];

    try {
      // Process each operation
      for (final operation in _pendingOperations) {
        if (operation.item != null) {
          bool operationSuccess = false;
          
          switch (operation.type) {
            case 'create':
              final result = await ApiService.createItem(operation.item!);
              if (result['success'] == true) {
                // Mark as synced
                await _markItemAsSynced(operation.item!, result['apiId']);
                operationSuccess = true;
              }
              break;
              
            case 'update':
              final result = await ApiService.updateItem(operation.item!);
              if (result['success'] == true) {
                await _markItemAsSynced(operation.item!, null);
                operationSuccess = true;
              }
              break;
              
            case 'delete':
              final result = await ApiService.deleteItem(operation.item!.id);
              if (result['success'] == true) {
                operationSuccess = true;
              }
              break;
          }
          
          if (operationSuccess) {
            processedIds.add(operation.id);
            successCount++;
          }
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Remove processed operations
      _pendingOperations.removeWhere((op) => processedIds.contains(op.id));
      await _saveOperations();

      _isSyncing = false;

      return {
        'success': successCount > 0,
        'message': successCount > 0 ? 'Synced $successCount items' : '',
        'synced': successCount,
      };

    } catch (e) {
      _isSyncing = false;
      return {'success': false, 'message': ''};
    }
  }

  // Mark item as synced in local storage
  Future<void> _markItemAsSynced(Item item, String? apiId) async {
    final items = await StorageService.loadItems();
    final index = items.indexWhere((i) => i.id == item.id);
    
    if (index != -1) {
      final updatedItem = item.copyWith(
        id: apiId != null ? 'CLOUD-$apiId' : item.id,
        isSynced: true,
      );
      items[index] = updatedItem;
      await StorageService.saveItems(items);
    }
  }

  // Get pending operations count
  int get pendingCount => _pendingOperations.length;

  // Get sync status
  bool get isSyncing => _isSyncing;

  // Clear all operations
  Future<void> clear() async {
    _pendingOperations.clear();
    await _saveOperations();
  }
}