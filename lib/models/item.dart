class Item {
  final String id;
  final String name;
  final String description;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: json['isSynced'] ?? false,
    );
  }

  Item copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    bool? isSynced,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, price: $price, synced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class PendingOperation {
  final String id;
  final String type; // 'create', 'update', 'delete'
  final Item? item;
  final DateTime timestamp;

  PendingOperation({
    required this.id,
    required this.type,
    this.item,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'item': item?.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: json['type'],
      item: json['item'] != null ? Item.fromJson(json['item']) : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}