# 📦 **Inventory App - README.md**

```markdown
# Inventory Manager

A Flutter-based inventory management app with offline support, CRUD operations, and mock API integration.

## ✨ Features

- Complete CRUD - Create, Read, Update, Delete items
- Offline Support - Works without internet, syncs when online
- Mock API - Simulated cloud storage with sample data
- Smart Sync - Queue system for offline changes
- Beautiful UI - Modern design with status badges
- Search - Filter items by name, ID, or description

## 🚀 Tech Stack

- Flutter & Dart
- SharedPreferences (local storage)
- UUID (unique IDs)

## 📱 Quick Start

```bash
git clone https://github.com/yourusername/inventory_app.git
cd inventory_app
flutter pub get
flutter run -d chrome
```

## 🎯 Key Features

| Feature | Description |
|---------|-------------|
| **Add Item** | Form validation for name, description, price |
| **Edit Item** | Pre-filled form with update capability |
| **Delete Item** | Confirmation dialog before removal |
| **Search** | Real-time filtering |
| **Sync** | Queue-based offline sync |

## 📊 Data Flow

```
User Action → Local Storage → UI Update
     ↓
Add to Sync Queue
     ↓
When Online → Mock API → Update Status
```

## 🎨 Visual Indicators

- 🟢 **Green Badge** - Synced with cloud
- 🟠 **Orange Badge** - Local only (pending sync)

## 📦 Sample Cloud Items

- Wireless Mouse (₹1,299)
- Mechanical Keyboard (₹4,599)
- Gaming Monitor (₹21,999)
- Laptop Stand (₹1,999)
- USB-C Hub (₹2,499)

## 🔧 Dependencies

```yaml
shared_preferences: ^2.2.2  # Local storage
uuid: ^4.3.3                 # Unique IDs
```

## 📱 Platform Support

- ✅ Android & iOS
- ✅ Web (Chrome)
- ✅ Windows & macOS


---

## 🚀 Run Locally

```bash
flutter pub get && flutter run -d chrome
```
