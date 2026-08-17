# Flutter Performance Optimization Guide

## Build Configuration

### 1. Release Mode (10x faster than debug)
```bash
# Always run in release mode for performance testing
flutter run --release

# Build optimized APK
flutter build apk --release --split-per-abi

# Build optimized iOS
flutter build ios --release
```

### 2. Enable Dart Compilation Optimizations
Add to `android/app/build.gradle`:
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
        }
    }
}
```

### 3. Tree Shaking for Icons
Only include used icons in `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  # Consider using flutter_launcher_icons for custom icons
```

---

## Code Optimizations

### 1. Use const Constructors
```dart
// BAD - rebuilds every time
Container(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)

// GOOD - reused instance
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)
```

### 2. Optimize Image Loading
```dart
// Use cached network images
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 300, // Reduce memory usage
  placeholder: (context, url) => const ShimmerPlaceholder(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)
```

### 3. ListView Optimization
```dart
// Use builder for long lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
  // Add cache extent for smoother scrolling
  cacheExtent: 500,
)
```

### 4. Avoid Expensive Operations in Build
```dart
// BAD - computed every build
Widget build(BuildContext context) {
  final filtered = items.where((i) => i.active).toList(); // Expensive!
  return ListView.builder(...);
}

// GOOD - compute once, store in state
final filteredItems = []; // Updated only when items change
```

---

## Supabase Optimizations

### 1. Connection Reuse
```dart
// Use singleton pattern
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static SupabaseClient get client => _client;
}
```

### 2. Parallel Queries
```dart
// BAD - sequential
final user = await supabase.from('profiles').select().single();
final wallet = await supabase.from('wallets').select().single();

// GOOD - parallel
final results = await Future.wait([
  supabase.from('profiles').select().single(),
  supabase.from('wallets').select().single(),
]);
final user = results[0];
final wallet = results[1];
```

### 3. Select Only Needed Columns
```dart
// BAD - fetches all columns
await supabase.from('profiles').select();

// GOOD - fetches only needed
await supabase.from('profiles').select('id, full_name, photo_url');
```

### 4. Use Real-time Subscriptions Wisely
```dart
// Only subscribe to what you need
supabase
  .from('messages')
  .stream(primaryKey: ['id'])
  .eq('chat_id', chatId)
  .order('created_at')
  .limit(50) // Limit initial fetch
  .listen((data) => updateMessages(data));
```

---

## State Management

### 1. Riverpod with AutoDispose
```dart
@riverpod
class Messages extends _$Messages {
  @override
  Future<List<Message>> build(String chatId) async {
    // Auto-disposed when widget unmounts
    return await fetchMessages(chatId);
  }
}
```

### 2. Selective Rebuilds
```dart
// Only rebuild when specific property changes
Consumer(
  builder: (context, ref, child) {
    final name = ref.watch(userProvider.select((u) => u.name));
    return Text(name);
  },
)
```

---

## Startup Optimization

### 1. Defer Non-Critical Init
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Critical init only
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const MyApp());
  
  // Defer non-critical
  Future.delayed(Duration.zero, () {
    FirebaseMessaging.instance.getToken();
    // Other non-critical setup
  });
}
```

### 2. Splash Screen Optimization
Use native splash screens (`flutter_native_splash`) for instant perceived performance.

---

## Memory Management

### 1. Dispose Controllers
```dart
@override
void dispose() {
  _scrollController.dispose();
  _textController.dispose();
  _animationController.dispose();
  super.dispose();
}
```

### 2. Cancel Subscriptions
```dart
StreamSubscription? _subscription;

@override
void initState() {
  _subscription = stream.listen((data) => setState(() => _data = data));
  super.initState();
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

---

## Target Performance Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Cold Start | < 2s | `flutter run --release`, time from tap to first frame |
| Login Flow | < 1s | Time from button tap to dashboard render |
| Screen Transition | < 300ms | DevTools Performance tab |
| List Scroll | 60fps | DevTools Performance overlay |
| Memory Usage | < 150MB | DevTools Memory tab |

### Enable Performance Overlay
```dart
MaterialApp(
  showPerformanceOverlay: true, // Debug only
)
```

### Profile Mode Testing
```bash
flutter run --profile
```
This enables performance tracking without debug overhead.
