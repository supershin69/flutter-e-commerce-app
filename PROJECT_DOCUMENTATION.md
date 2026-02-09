# E-Commerce Flutter Application - Complete Documentation

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture & Design Patterns](#architecture--design-patterns)
3. [Technical Stack](#technical-stack)
4. [Project Structure](#project-structure)
5. [Database Schema & Supabase Integration](#database-schema--supabase-integration)
6. [Core Workflows](#core-workflows)
7. [Key Features & Components](#key-features--components)
8. [State Management](#state-management)
9. [UI/UX Design System](#uiux-design-system)
10. [Authentication & Security](#authentication--security)
11. [Payment & Checkout Flow](#payment--checkout-flow)
12. [Development Guidelines](#development-guidelines)
13. [API Integration](#api-integration)
14. [Future Enhancements](#future-enhancements)

---

## 🎯 Project Overview

This is a **Flutter-based e-commerce mobile application** for a gadget/electronics store. The app provides a complete shopping experience including product browsing, cart management, order placement, and user profile management. It integrates with **Supabase** as the backend-as-a-service (BaaS) for authentication, database operations, and real-time data synchronization.

### Key Characteristics:
- **Platform**: Cross-platform (Android, iOS, Web, Windows, macOS, Linux)
- **Backend**: Supabase (PostgreSQL database, Authentication, Real-time subscriptions)
- **State Management**: Flutter's built-in StatefulWidget (no external state management library)
- **Local Storage**: SharedPreferences for cart persistence
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Architecture**: Feature-based folder structure with service layer

---

## 🏗️ Architecture & Design Patterns

### Architecture Pattern
The application follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────┐
│         Presentation Layer           │
│  (Screens, Widgets, UI Components)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Service Layer                │
│  (CartService, CheckoutService,    │
│   UserService - Business Logic)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Data Layer                  │
│  (Models, Supabase Client,         │
│   SharedPreferences)                │
└─────────────────────────────────────┘
```

### Design Patterns Used:
1. **Service Pattern**: Business logic encapsulated in service classes (`CartService`, `CheckoutService`, `UserService`)
2. **Repository Pattern**: Models handle data transformation (`fromMap`, `toJson`, `fromDatabaseMap`)
3. **Factory Pattern**: Model constructors for creating instances from different data sources
4. **Singleton Pattern**: Supabase client instance accessed globally
5. **Observer Pattern**: StreamBuilder for reactive UI updates (auth state, notifications)

### Folder Structure Philosophy:
- **Feature-based organization**: Related screens, models, and logic grouped by feature
- **Separation of concerns**: Models, services, screens, and widgets in separate directories
- **Reusability**: Common widgets and utilities extracted to shared locations

---

## 🛠️ Technical Stack

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | Core Flutter framework |
| `supabase_flutter` | ^2.12.0 | Backend integration (Auth, Database, Storage) |
| `firebase_core` | ^4.3.0 | Firebase initialization |
| `firebase_messaging` | ^16.1.0 | Push notifications |
| `flutter_local_notifications` | ^19.5.0 | Local notification display |
| `shared_preferences` | ^2.2.2 | Local storage (cart persistence) |
| `uuid` | ^4.3.3 | Unique ID generation |
| `image_picker` | ^1.0.7 | Image selection from device |
| `intl` | ^0.19.0 | Internationalization & number formatting |
| `flutter_svg` | ^2.2.3 | SVG image rendering |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

### Development Tools
- **Flutter SDK**: 3.10.1+
- **Dart**: 3.10.1+
- **Linter**: flutter_lints ^6.0.0

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point, Supabase & Firebase initialization
├── features/                          # Feature-based modules
│   ├── personalization/
│   │   └── screens/
│   │       └── orders/                # Order history & details
│   │           ├── orders.dart        # Order list screen
│   │           └── order_detail_screen.dart
│   └── shop/
│       ├── models/
│       │   └── order_model.dart       # Order data model
│       └── screens/
│           └── checkout/
│               ├── checkout_voucher.dart  # Order summary & checkout
│               └── order_success_page.dart
├── models/                            # Data models
│   ├── user_model.dart
│   ├── product_model.dart
│   ├── cart_item_model.dart
│   ├── category_model.dart
│   ├── brand_model.dart
│   └── variant_attribute_model.dart
├── screens/                           # Main application screens
│   ├── flash_screen.dart              # Splash screen
│   ├── home_screen.dart               # Home page with banners & categories
│   ├── store/
│   │   ├── store_page.dart            # Store browsing with categories
│   │   └── store_search_bar.dart
│   ├── products_page.dart             # Product listing
│   ├── product_detail_page.dart       # Product details & variant selection
│   ├── cart_page.dart                 # Shopping cart
│   ├── wishlist_page.dart             # Wishlist management
│   ├── CategoriesPage.dart            # Category selection
│   ├── brands_page.dart               # Brand selection
│   ├── all_brands_page.dart
│   ├── ProfilePage.dart               # User profile
│   ├── NotificationPage.dart          # Push notifications
│   ├── order_page.dart                # Legacy order page
│   ├── store_search_results_page.dart
│   └── auth/
│       └── auth_gate.dart             # Authentication wrapper
├── services/                         # Business logic layer
│   ├── cart_service.dart              # Cart CRUD operations
│   ├── checkout_service.dart          # Order creation & retrieval
│   └── user_service.dart              # User profile management
├── utils/                             # Utilities
│   └── colors.dart                    # App color constants
└── widgets/                           # Reusable UI components
    ├── bottom_nav_bar.dart            # Bottom navigation bar
    ├── product_action_bar.dart        # Product action buttons
    └── transparent_appbar.dart        # Transparent app bar
```

---

## 🗄️ Database Schema & Supabase Integration

### Supabase Configuration
- **URL**: `https://mxngcloeolzkfnauioln.supabase.co`
- **Authentication**: PKCE flow (OAuth with Google)
- **Database**: PostgreSQL with Row Level Security (RLS)

### Key Database Tables

#### 1. **orders** Table
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  total_amount INT4 NOT NULL,
  status order_status NOT NULL DEFAULT 'processing',
  payment_status payment_status NOT NULL DEFAULT 'pending',
  shipping_address JSONB NOT NULL,
  payment_method TEXT,
  shipping_method TEXT,
  customer_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT shipping_address_required_fields 
    CHECK (shipping_address ? 'city' AND shipping_address ? 'street')
);
```

**Enums:**
- `order_status`: `pending`, `processing`, `shipped`, `delivered`, `canceled`
- `payment_status`: `pending`, `paid`, `failed`, `refunded`

**JSONB Structure (`shipping_address`):**
```json
{
  "city": "Mandalay",           // Required
  "street": "73 x 74",          // Required
  "phone": "+959123456789",
  "name": "John Doe",
  "items": [...],               // Cart items array
  "receipt_url": "https://..."  // Optional payment receipt
}
```

#### 2. **profiles** Table
```sql
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  name TEXT,
  avatar TEXT,
  phone TEXT,
  address TEXT,
  fcm_token TEXT,              -- Firebase Cloud Messaging token
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

#### 3. **product_catalog** View
A Supabase view that aggregates product data with variants, images, categories, and brands:
- Product information
- Variant details (price, quantity, attributes)
- Product images
- Category and brand names

#### 4. **products** Table
- Product base information
- Relationships to `categories`, `brands`, `variants`, `images`

### Data Flow
1. **Read Operations**: Direct Supabase queries using `.from('table').select()`
2. **Write Operations**: Service layer methods handle data transformation and validation
3. **Real-time**: Can be extended with Supabase real-time subscriptions
4. **Authentication**: Supabase Auth handles user sessions and OAuth

---

## 🔄 Core Workflows

### 1. User Authentication Flow

```
┌─────────────┐
│ App Launch  │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Splash Screen   │ (4 seconds)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ AuthGate Check  │
└──────┬──────────┘
       │
   ┌───┴───┐
   │       │
   ▼       ▼
┌─────┐ ┌──────────┐
│Auth │ │ Not Auth │
└──┬──┘ └────┬─────┘
   │         │
   │         ▼
   │    ┌─────────────┐
   │    │ Login Page  │
   │    │ (Google OAuth)│
   │    └──────┬──────┘
   │           │
   │           ▼
   │    ┌─────────────┐
   │    │ OAuth Flow  │
   │    └──────┬──────┘
   │           │
   └───────────┘
       │
       ▼
┌─────────────────┐
│ HomePage        │
│ (Bottom Nav)    │
└─────────────────┘
```

**Implementation Details:**
- `AuthGate` widget uses `StreamBuilder<AuthState>` to monitor authentication
- Google OAuth redirects to `ecommerce://login-callback`
- FCM token is automatically saved to `profiles.fcm_token` after login
- Session persistence handled by Supabase Auth

### 2. Product Browsing Flow

```
Home Screen
    │
    ├───► Categories Page
    │         │
    │         ├───► Brands Page (by category)
    │         │         │
    │         │         └───► Products Page (by category + brand)
    │         │                   │
    │         │                   └───► Product Detail Page
    │         │
    │         └───► All Brands Page
    │
    └───► Store Page
              │
              ├───► Category Tabs
              │
              └───► Brand Grid
                      │
                      └───► Products Page
```

**Key Features:**
- **Category Navigation**: Home → Categories → Brands → Products
- **Store Page**: Direct category-based browsing with brand filtering
- **Search**: Store search bar for product search
- **Product Catalog View**: Uses Supabase `product_catalog` view for optimized queries

### 3. Shopping Cart Flow

```
Product Detail Page
    │
    ├───► Select Variant (Color, Size, etc.)
    │
    ├───► Choose Quantity
    │
    └───► Add to Cart
            │
            ▼
    ┌───────────────┐
    │ CartService   │
    │ (SharedPrefs) │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ Cart Page     │
    │ - View Items  │
    │ - Update Qty  │
    │ - Remove     │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ Checkout      │
    └───────────────┘
```

**Cart Persistence:**
- Stored locally using `SharedPreferences`
- JSON serialization of `CartItem` objects
- Persists across app restarts
- No server-side cart (client-side only)

**Cart Operations:**
- `addToCart()`: Adds item or increments quantity if exists
- `updateQuantity()`: Updates quantity or removes if <= 0
- `removeFromCart()`: Removes item by ID
- `getCartCount()`: Returns total item count
- `getTotalPrice()`: Calculates cart total

### 4. Checkout & Order Placement Flow

```
Cart Page
    │
    └───► Checkout Voucher Screen
            │
            ├───► Load User Data (name, phone, address)
            │
            ├───► Shipping Address Input
            │     - City (required)
            │     - Street (required)
            │
            ├───► Payment Method Selection
            │     - Cash on Delivery
            │     - K-Pay (QR code)
            │     - Wave Pay (QR code)
            │     - AYA Pay (QR code)
            │
            ├───► Order Summary
            │     - Items list
            │     - Subtotal
            │     - Total
            │
            └───► Confirm Order
                  │
                  ▼
          ┌───────────────┐
          │ CheckoutService│
          │ .createOrder() │
          └───────┬───────┘
                  │
                  ▼
          ┌───────────────┐
          │ Supabase      │
          │ orders table  │
          └───────┬───────┘
                  │
                  ▼
          ┌───────────────┐
          │ Order Success │
          │ Page          │
          └───────────────┘
                  │
                  ▼
          ┌───────────────┐
          │ Clear Cart    │
          └───────────────┘
```

**Order Creation Requirements:**
1. **User Authentication**: Must be logged in (`user_id` is NOT NULL)
2. **Shipping Address**: Must include `city` and `street` (database constraint)
3. **Payment Method**: Defaults to "cash-on-delivery" if not specified
4. **Order Status**: Defaults to "processing"
5. **Payment Status**: Defaults to "pending"

**Order Data Structure:**
```dart
{
  'id': UUID,
  'user_id': UUID (required),
  'total_amount': int,
  'status': 'processing' | 'pending' | 'shipped' | 'delivered' | 'canceled',
  'payment_status': 'pending' | 'paid' | 'failed' | 'refunded',
  'shipping_address': {
    'city': String (required),
    'street': String (required),
    'phone': String,
    'name': String,
    'items': List<CartItem>,
    'receipt_url': String? (optional)
  },
  'payment_method': String?,
  'shipping_method': String?,
  'customer_name': String?,
  'created_at': DateTime
}
```

### 5. Order Management Flow

```
Profile Page
    │
    └───► My Orders
            │
            ├───► Order List Screen
            │     - Order cards with:
            │       * Short Order ID (#7B7BC9DB)
            │       * Status badge (color-coded)
            │       * Date, Items count, Total
            │
            └───► Order Detail Screen
                  - Full order information
                  - Shipping details
                  - Order items
                  - Total summary
                  - Copy Order ID button
```

**Order Status Colors:**
- `pending`: Orange
- `processing`: Blue
- `shipped`: Purple
- `delivered`: Green
- `canceled`/`cancelled`: Red

---

## 🎨 Key Features & Components

### 1. Product Variant System
- **Multi-attribute variants**: Products can have variants based on attributes (e.g., Color, Storage, Size)
- **Dynamic pricing**: Each variant has its own price
- **Image association**: Images can be linked to specific variant attributes
- **Stock management**: Variant-level quantity tracking

**Implementation:**
- `ProductVariant` model with `attributes` list
- `VariantAttribute` model for attribute-value pairs
- Selection state managed in `ProductDetails` widget
- Price and images update dynamically based on selection

### 2. Shopping Cart System
- **Local persistence**: Cart stored in SharedPreferences
- **Quantity management**: Increment/decrement with validation
- **Duplicate handling**: Same product+variant increments quantity
- **Real-time totals**: Cart total calculated on-the-fly

### 3. Payment Integration
- **Multiple payment methods**:
  - Cash on Delivery (default)
  - K-Pay (with QR code)
  - Wave Pay (with QR code)
  - AYA Pay (with QR code)
- **QR Code Display**: Dynamic QR code images based on payment method
- **Smooth UI**: StatefulBuilder prevents scroll jumps when selecting payment

### 4. Order Tracking
- **Order history**: Chronological list of user orders
- **Order details**: Complete order information with items
- **Status tracking**: Visual status badges with color coding
- **Order ID formatting**: Shortened IDs (#7B7BC9DB) with copy functionality

### 5. Push Notifications
- **Firebase Cloud Messaging**: Integrated for push notifications
- **Token management**: FCM token stored in user profile
- **Foreground handling**: Local notifications displayed when app is open
- **Background handling**: Background message handler configured

### 6. Search Functionality
- **Store search**: Search bar in store page
- **Category filtering**: Filter products by category
- **Brand filtering**: Filter products by brand

### 7. Wishlist (Placeholder)
- Wishlist page exists but functionality may be incomplete
- Can be extended with Supabase integration

---

## 📱 State Management

### Current Approach
The app uses **Flutter's built-in state management**:
- **StatefulWidget**: For local component state
- **setState()**: For UI updates
- **FutureBuilder**: For async data loading
- **StreamBuilder**: For reactive data (auth state)

### State Management Patterns:

#### 1. **Local State (StatefulWidget)**
```dart
class _ProductDetailState extends State<ProductDetails> {
  bool isWishlisted = false;
  Map<String, VariantAttribute> selectedAttributes = {};
  ProductVariant? currentVariant;
  
  void _updateSelection() {
    setState(() {
      // Update state
    });
  }
}
```

#### 2. **Service-Based State (FutureBuilder)**
```dart
FutureBuilder<List<CartItem>>(
  future: _cartService.getCartItems(),
  builder: (context, snapshot) {
    // Build UI based on async data
  },
)
```

#### 3. **Reactive State (StreamBuilder)**
```dart
StreamBuilder<AuthState>(
  stream: supabase.auth.onAuthStateChange,
  builder: (context, snapshot) {
    // React to auth changes
  },
)
```

### Potential Improvements:
- Consider **Provider** or **Riverpod** for global state (cart, user)
- **GetX** or **Bloc** for complex state management
- **StatefulBuilder** already used for localized updates (payment method selection)

---

## 🎨 UI/UX Design System

### Color Theme
**Primary Colors:**
- **Brown**: `Colors.brown.shade300` - Primary brand color
  - Used for: App bars, buttons, icons, Order IDs, totals
- **White**: `Colors.white` - Background
- **Grey**: `Color(0xFF9AA0A6)` - Muted text
- **Dark**: `Color(0xFF333333)` - Primary text

**Status Colors:**
- Pending: `Colors.orange`
- Processing: `Colors.blue`
- Shipped: `Colors.purple`
- Delivered: `Colors.green`
- Canceled: `Colors.red`

### Typography
- **Headings**: Bold, 16-28px
- **Body**: Regular, 12-14px
- **Labels**: Medium weight, 12px
- **Order IDs**: Bold, uppercase, letter-spacing: 0.5

### Components

#### 1. **Bottom Navigation Bar**
- Brown background (`Colors.brown.shade300`)
- White icons and text
- Active indicator with white circle background
- 4 tabs: Home, Store, Wishlist, Profile

#### 2. **Order Cards**
- White background with subtle shadow
- Rounded corners (12px)
- Status badge with color-coded background
- Short Order ID with brown color
- Formatted currency (comma separators)

#### 3. **Product Cards**
- Rounded images
- Price display
- Discount badges
- Wishlist icon

#### 4. **Checkout Screen**
- Two-column address input (City, Street)
- Payment method selector with QR codes
- Order summary with itemized list
- Smooth transitions (AnimatedSize, StatefulBuilder)

### Number Formatting
- **Currency**: Uses `intl` package with `NumberFormat('#,###')`
- **Format**: `6,000,000 MMK` (Myanmar Kyat)
- Applied to: Cart totals, order totals, product prices

---

## 🔐 Authentication & Security

### Authentication Method
- **Provider**: Google OAuth (via Supabase)
- **Flow**: PKCE (Proof Key for Code Exchange)
- **Redirect**: `ecommerce://login-callback`

### Security Features
1. **Row Level Security (RLS)**: Supabase enforces database-level security
2. **Session Management**: Handled by Supabase Auth
3. **Token Storage**: Secure token storage (managed by Supabase)
4. **User Data Isolation**: Users can only access their own orders

### Authentication Flow
```dart
// Sign in with Google
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'ecommerce://login-callback',
);

// Monitor auth state
StreamBuilder<AuthState>(
  stream: supabase.auth.onAuthStateChange,
  builder: (context, snapshot) {
    final session = snapshot.data?.session;
    if (session != null) {
      // User is authenticated
    } else {
      // Show login page
    }
  },
)
```

### User Profile Management
- Profile data fetched from `profiles` table
- FCM token automatically updated on login
- Shipping address and phone number editable

---

## 💳 Payment & Checkout Flow

### Payment Methods Supported

1. **Cash on Delivery (COD)**
   - Default payment method
   - No additional UI required
   - Stored as: `'cash-on-delivery'`

2. **Mobile Banking (QR Code Payment)**
   - **K-Pay**: QR code from `assets/images/payment/kpay.jpg`
   - **Wave Pay**: QR code from `assets/images/payment/wave_pay.png`
   - **AYA Pay**: QR code from `assets/images/payment/aya_pay.png`
   - Stored as: `'KPay'`, `'WavePay'`, `'AYAPay'`

### Checkout Process

1. **Pre-checkout Validation**:
   - User must be authenticated
   - Cart must not be empty
   - City and Street must be provided

2. **Order Creation**:
   - UUID generated for order ID
   - Cart items serialized into `shipping_address.items`
   - Order inserted into Supabase `orders` table

3. **Post-checkout**:
   - Cart cleared
   - Success page displayed
   - Order ID shown (shortened format)

### Payment Status Tracking
- `pending`: Initial status
- `paid`: Updated when payment confirmed (manual/admin)
- `failed`: Payment failed
- `refunded`: Refund processed

---

## 📝 Development Guidelines

### Code Style
- **Naming**: camelCase for variables, PascalCase for classes
- **File naming**: snake_case for files (e.g., `order_detail_screen.dart`)
- **Widget organization**: Separate widgets into reusable components
- **Error handling**: Try-catch blocks with user-friendly error messages

### Best Practices

1. **Model Design**:
   - Use factory constructors for different data sources (`fromMap`, `fromJson`, `fromDatabaseMap`)
   - Include `copyWith` methods for immutable updates
   - Add computed getters for derived data

2. **Service Layer**:
   - Encapsulate business logic in service classes
   - Return `Future<bool>` for operations that can fail
   - Use `debugPrint` for logging (not `print`)

3. **UI Components**:
   - Extract reusable widgets
   - Use `const` constructors where possible
   - Implement proper loading and error states

4. **Database Integration**:
   - Always validate data before insertion
   - Handle JSONB parsing carefully (can be Map or String)
   - Use type-safe queries with proper error handling

### Error Handling Patterns

```dart
// Service method pattern
Future<OrderModel?> createOrder({...}) async {
  try {
    // Database operation
    final response = await supabase.from('orders').insert(...);
    return OrderModel.fromDatabaseMap(response);
  } catch (e, stackTrace) {
    debugPrint('Error creating order: $e');
    debugPrint('Stack trace: $stackTrace');
    throw Exception('Failed to create order: $e');
  }
}

// UI error handling
FutureBuilder(
  future: _ordersFuture,
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return ErrorWidget(snapshot.error);
    }
    // ...
  },
)
```

---

## 🔌 API Integration

### Supabase Client Usage

```dart
final supabase = Supabase.instance.client;

// Read operation
final data = await supabase
    .from('orders')
    .select()
    .eq('user_id', userId)
    .order('created_at', ascending: false);

// Write operation
final response = await supabase
    .from('orders')
    .insert(orderData)
    .select()
    .single();

// Update operation
await supabase
    .from('profiles')
    .update({'phone': phoneNumber})
    .eq('user_id', user.id);
```

### Key Supabase Features Used
1. **Authentication**: OAuth, session management
2. **Database**: PostgreSQL queries, JSONB support
3. **Real-time**: Can be extended for live updates
4. **Storage**: Can be used for image uploads (not currently implemented)

### Data Transformation
- **Database → Model**: `fromDatabaseMap()` handles type conversion
- **Model → Database**: `toJson()` or direct map construction
- **JSONB Handling**: Parses both Map and String formats

---

## 🚀 Future Enhancements

### Recommended Improvements

1. **State Management**
   - Implement Provider or Riverpod for global state
   - Centralize cart state management
   - Add user state management

2. **Offline Support**
   - Implement local database (SQLite) for offline cart
   - Sync cart when online
   - Cache product data

3. **Real-time Features**
   - Order status updates via Supabase real-time
   - Live inventory updates
   - Chat support

4. **Payment Integration**
   - Integrate actual payment gateways
   - Payment receipt upload
   - Payment status webhooks

5. **Enhanced Search**
   - Full-text search
   - Filters (price range, brand, category)
   - Search history

6. **User Features**
   - Wishlist with Supabase persistence
   - Order reviews and ratings
   - Address book management

7. **Performance**
   - Image caching
   - Lazy loading for product lists
   - Pagination for large datasets

8. **Analytics**
   - User behavior tracking
   - Order analytics
   - Product popularity metrics

9. **Admin Features**
   - Admin dashboard (separate app or web)
   - Order management
   - Product management
   - Inventory management

10. **Testing**
    - Unit tests for services
    - Widget tests for UI components
    - Integration tests for workflows

---

## 📚 Additional Resources

### Key Files Reference

- **Main Entry**: `lib/main.dart`
- **Auth Gate**: `lib/screens/auth/auth_gate.dart`
- **Home**: `lib/screens/home_screen.dart`
- **Store**: `lib/screens/store/store_page.dart`
- **Cart**: `lib/screens/cart_page.dart`
- **Checkout**: `lib/features/shop/screens/checkout/checkout_voucher.dart`
- **Orders**: `lib/features/personalization/screens/orders/orders.dart`

### Service Files
- **Cart**: `lib/services/cart_service.dart`
- **Checkout**: `lib/services/checkout_service.dart`
- **User**: `lib/services/user_service.dart`

### Model Files
- **Order**: `lib/features/shop/models/order_model.dart`
- **Product**: `lib/models/product_model.dart`
- **Cart Item**: `lib/models/cart_item_model.dart`
- **User**: `lib/models/user_model.dart`

---

## 🐛 Known Issues & Considerations

1. **Cart Persistence**: Cart is local-only, not synced across devices
2. **Guest Checkout**: Not supported (requires authentication)
3. **Wishlist**: May be incomplete or placeholder
4. **Image Loading**: No explicit caching strategy
5. **Error Messages**: Some error messages could be more user-friendly
6. **Loading States**: Some screens may need better loading indicators

---

## 📞 Support & Maintenance

### Environment Setup
1. Clone repository
2. Run `flutter pub get`
3. Configure Supabase credentials in `lib/main.dart`
4. Configure Firebase in `android/app/google-services.json` and `ios/`
5. Run `flutter run`

### Database Migrations
- Database schema managed in Supabase dashboard
- No migration files in codebase
- Schema changes require manual updates to models and services

---

**Documentation Version**: 1.0  
**Last Updated**: 2024  
**Project**: Flutter E-Commerce Application
