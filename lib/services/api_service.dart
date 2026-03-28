import '../models/item.dart';

class ApiService {
  // MOCK API - Always works, no internet needed
  // Simulates cloud storage with dummy data
  
  // Get mock items from "cloud"
  static Future<List<Item>> fetchItems() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return predefined mock data
    return [
      Item(
        id: 'CLOUD-001',
        name: 'Wireless Mouse',
        description: 'Premium wireless mouse with ergonomic design',
        price: 1299.99,
        isSynced: true,
      ),
      Item(
        id: 'CLOUD-002',
        name: 'Mechanical Keyboard',
        description: 'RGB mechanical keyboard with blue switches',
        price: 4599.99,
        isSynced: true,
      ),
      Item(
        id: 'CLOUD-003',
        name: 'Gaming Monitor',
        description: '27-inch 144Hz gaming monitor with 1ms response',
        price: 21999.99,
        isSynced: true,
      ),
      Item(
        id: 'CLOUD-004',
        name: 'Laptop Stand',
        description: 'Adjustable aluminum laptop stand for better ergonomics',
        price: 1999.99,
        isSynced: true,
      ),
      Item(
        id: 'CLOUD-005',
        name: 'USB-C Hub',
        description: '7-in-1 USB-C hub with 4K HDMI, Ethernet, and SD card slots',
        price: 2499.99,
        isSynced: true,
      ),
    ];
  }

  // Create item in mock API
  static Future<Map<String, dynamic>> createItem(Item item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Generate a mock API ID
    final apiId = DateTime.now().millisecondsSinceEpoch.toString();
    
    return {
      'success': true,
      'message': 'Item created in cloud',
      'apiId': apiId,
    };
  }

  // Update item in mock API
  static Future<Map<String, dynamic>> updateItem(Item item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'success': true,
      'message': 'Item updated in cloud',
    };
  }

  // Delete item from mock API
  static Future<Map<String, dynamic>> deleteItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'success': true,
      'message': 'Item deleted from cloud',
    };
  }

  // Mock connection check - always returns true
  static Future<bool> checkConnection() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true; // Mock API always works
  }
}