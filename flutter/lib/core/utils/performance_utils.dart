/// Performance utilities for Flutter app
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// LRU Cache for caching data
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  LRUCache({this.maxSize = 100});

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void set(K key, V value) {
    _cache.remove(key);
    _cache[key] = value;
    
    // Evict oldest entries if over capacity
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  bool has(K key) => _cache.containsKey(key);
  
  void remove(K key) => _cache.remove(key);
  
  void clear() => _cache.clear();
  
  int get size => _cache.length;
}

/// Debouncer for limiting rapid calls
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

/// Throttler for rate limiting
class Throttler {
  final Duration interval;
  DateTime? _lastCall;
  Timer? _pendingTimer;

  Throttler({this.interval = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastCall == null || now.difference(_lastCall!) >= interval) {
      _lastCall = now;
      action();
    } else {
      _pendingTimer?.cancel();
      final remaining = interval - now.difference(_lastCall!);
      _pendingTimer = Timer(remaining, () {
        _lastCall = DateTime.now();
        action();
      });
    }
  }

  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  void dispose() {
    cancel();
  }
}

/// Request batcher for combining multiple requests
class RequestBatcher<K, V> {
  final Future<Map<K, V>> Function(List<K> keys) batchFn;
  final Duration delay;
  
  final Map<K, List<Completer<V>>> _pending = {};
  Timer? _timer;

  RequestBatcher({
    required this.batchFn,
    this.delay = const Duration(milliseconds: 10),
  });

  Future<V> get(K key) {
    final completer = Completer<V>();
    
    _pending.putIfAbsent(key, () => []).add(completer);
    
    _timer?.cancel();
    _timer = Timer(delay, _flush);
    
    return completer.future;
  }

  Future<void> _flush() async {
    final batch = Map<K, List<Completer<V>>>.from(_pending);
    _pending.clear();
    
    try {
      final keys = batch.keys.toList();
      final results = await batchFn(keys);
      
      for (final entry in batch.entries) {
        final result = results[entry.key];
        for (final completer in entry.value) {
          if (result != null) {
            completer.complete(result);
          } else {
            completer.completeError(Exception('No result for key: ${entry.key}'));
          }
        }
      }
    } catch (e) {
      for (final completers in batch.values) {
        for (final completer in completers) {
          completer.completeError(e);
        }
      }
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Performance logger (debug only)
class PerfLogger {
  static final Map<String, DateTime> _marks = {};

  static void start(String name) {
    if (kDebugMode) {
      _marks[name] = DateTime.now();
    }
  }

  static Duration? end(String name) {
    if (kDebugMode) {
      final startTime = _marks.remove(name);
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        debugPrint('[Perf] $name: ${duration.inMilliseconds}ms');
        return duration;
      }
    }
    return null;
  }
}

/// Parallel execution with concurrency limit
Future<List<R>> parallelLimit<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) fn,
) async {
  final results = <R>[];
  final executing = <Future<void>>[];
  
  for (final item in items) {
    final future = fn(item).then((result) {
      results.add(result);
    });
    executing.add(future);
    
    if (executing.length >= limit) {
      await Future.any(executing);
      executing.removeWhere((f) => f == future);
    }
  }
  
  await Future.wait(executing);
  return results;
}

/// Chunk list for batch processing
List<List<T>> chunk<T>(List<T> list, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    chunks.add(list.sublist(i, (i + size > list.length) ? list.length : i + size));
  }
  return chunks;
}
