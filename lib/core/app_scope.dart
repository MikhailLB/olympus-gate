import 'package:flutter/widgets.dart';

import '../services/game_storage.dart';

/// Provides the shared [GameStorage] instance to the widget tree and rebuilds
/// dependents whenever the player profile changes.
class AppScope extends InheritedNotifier<GameStorage> {
  const AppScope({
    super.key,
    required GameStorage storage,
    required super.child,
  }) : super(notifier: storage);

  static GameStorage of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.notifier!;
  }

  /// Reads the storage without subscribing to rebuilds.
  static GameStorage read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
