import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';

class StorageService {
  static const String _itemsKey = 'inventory_items';
  static const String _operationsKey = 'pending_operations';
  static const String _lastSyncKey = 'last_sync_time';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // Save items to local storage
  static Future<void> saveItems(List<Item> items) async {
    final prefs = await _prefs;
    final itemsJson = items.map((item) => item.toJson()).toList();
    await prefs.setString(_itemsKey, json.encode(itemsJson));
  }

  // Load items from local storage
  static Future<List<Item>> loadItems() async {
    final prefs = await _prefs;
    final itemsJson = prefs.getString(_itemsKey);
    
    if (itemsJson == null || itemsJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = json.decode(itemsJson);
      return decoded.map((json) => Item.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save pending operations
  static Future<void> savePendingOperations(List<PendingOperation> operations) async {
    final prefs = await _prefs;
    final operationsJson = operations.map((op) => op.toJson()).toList();
    await prefs.setString(_operationsKey, json.encode(operationsJson));
  }

  // Load pending operations
  static Future<List<PendingOperation>> loadPendingOperations() async {
    final prefs = await _prefs;
    final operationsJson = prefs.getString(_operationsKey);
    
    if (operationsJson == null || operationsJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = json.decode(operationsJson);
      return decoded.map((json) => PendingOperation.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Clear all data
  static Future<void> clearAllData() async {
    final prefs = await _prefs;
    await prefs.remove(_itemsKey);
    await prefs.remove(_operationsKey);
    await prefs.remove(_lastSyncKey);
  }
}