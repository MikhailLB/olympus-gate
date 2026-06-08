import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/god.dart';
import '../models/mission.dart';

/// Persistent player profile backed by [SharedPreferences].
///
/// Exposes a [ChangeNotifier] so the UI (gold counter, unlocks, missions)
/// rebuilds whenever the profile changes.
class GameStorage extends ChangeNotifier {
  GameStorage._(this._prefs);

  final SharedPreferences _prefs;

  static const _kCoins = 'coins';
  static const _kSelectedGod = 'selected_god';
  static const _kUnlocked = 'unlocked_gods';
  static const _kClaimedMissions = 'claimed_missions';
  static const _kLastDaily = 'last_daily';
  static const _kSound = 'sound_on';
  static const _kHaptics = 'haptics_on';
  static const _kNotifAsked = 'notif_asked';
  static const _kNotifAllowed = 'notif_allowed';
  static const _kStatPrefix = 'stat_';

  static Future<GameStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = GameStorage._(prefs);
    storage._ensureDefaults();
    return storage;
  }

  void _ensureDefaults() {
    if (!_prefs.containsKey(_kUnlocked)) {
      _prefs.setStringList(_kUnlocked, [God.zeus.id]);
    }
    if (!_prefs.containsKey(_kSelectedGod)) {
      _prefs.setString(_kSelectedGod, God.zeus.id);
    }
  }

  // --- Gold ---------------------------------------------------------------
  int get coins => _prefs.getInt(_kCoins) ?? 0;

  Future<void> addCoins(int amount) async {
    if (amount == 0) return;
    await _prefs.setInt(_kCoins, (coins + amount).clamp(0, 1 << 31));
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (coins < amount) return false;
    await _prefs.setInt(_kCoins, coins - amount);
    notifyListeners();
    return true;
  }

  // --- Gods ---------------------------------------------------------------
  Set<String> get unlockedGods =>
      (_prefs.getStringList(_kUnlocked) ?? [God.zeus.id]).toSet();

  bool isUnlocked(String godId) => unlockedGods.contains(godId);

  String get selectedGodId => _prefs.getString(_kSelectedGod) ?? God.zeus.id;

  God get selectedGod => God.byId(selectedGodId);

  Future<void> selectGod(String godId) async {
    await _prefs.setString(_kSelectedGod, godId);
    notifyListeners();
  }

  /// Buys [god] if affordable and not already owned. Returns true on success.
  Future<bool> unlockGod(God god) async {
    if (isUnlocked(god.id)) return true;
    if (!await spendCoins(god.cost)) return false;
    final set = unlockedGods..add(god.id);
    await _prefs.setStringList(_kUnlocked, set.toList());
    await selectGod(god.id);
    return true;
  }

  // --- Stats --------------------------------------------------------------
  int stat(String key) => _prefs.getInt('$_kStatPrefix$key') ?? 0;

  Future<void> addStat(String key, int amount) async {
    await _prefs.setInt('$_kStatPrefix$key', stat(key) + amount);
  }

  /// Stores [value] only when it beats the previous record.
  Future<void> recordMax(String key, int value) async {
    if (value > stat(key)) {
      await _prefs.setInt('$_kStatPrefix$key', value);
    }
  }

  // --- Missions -----------------------------------------------------------
  Set<String> get claimedMissions =>
      (_prefs.getStringList(_kClaimedMissions) ?? const []).toSet();

  bool isMissionClaimed(String id) => claimedMissions.contains(id);

  Future<void> claimMission(String id, int reward) async {
    if (isMissionClaimed(id)) return;
    final set = claimedMissions..add(id);
    await _prefs.setStringList(_kClaimedMissions, set.toList());
    await addCoins(reward);
  }

  // --- Daily bonus --------------------------------------------------------
  /// Returns the streak day (1..7) claimable now, or 0 if already claimed today.
  bool get canClaimDaily {
    final last = _prefs.getString(_kLastDaily);
    if (last == null) return true;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    return today.isAfter(lastDay);
  }

  Future<void> claimDaily(int reward) async {
    await _prefs.setString(_kLastDaily, DateTime.now().toIso8601String());
    await addCoins(reward);
  }

  // --- Settings -----------------------------------------------------------
  bool get soundOn => _prefs.getBool(_kSound) ?? true;
  bool get hapticsOn => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setSound(bool v) async {
    await _prefs.setBool(_kSound, v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    await _prefs.setBool(_kHaptics, v);
    notifyListeners();
  }

  bool get notificationsAsked => _prefs.getBool(_kNotifAsked) ?? false;
  bool get notificationsAllowed => _prefs.getBool(_kNotifAllowed) ?? false;

  Future<void> setNotificationChoice(bool allowed) async {
    await _prefs.setBool(_kNotifAsked, true);
    await _prefs.setBool(_kNotifAllowed, allowed);
    notifyListeners();
  }

  /// Persists the results of a finished run and updates achievement stats.
  Future<void> recordRunResult({
    required int score,
    required int coinsEarned,
    required int wrathUsed,
    required int rocksSmashed,
    required int bestCombo,
  }) async {
    await addStat(StatKeys.gamesPlayed, 1);
    await addStat(StatKeys.totalCoins, coinsEarned);
    await addStat(StatKeys.wrathUnleashed, wrathUsed);
    await addStat(StatKeys.totalScore, score);
    await addStat(StatKeys.rocksSmashed, rocksSmashed);
    await recordMax(StatKeys.bestScore, score);
    await recordMax(StatKeys.bestCombo, bestCombo);
    await addCoins(coinsEarned);
    notifyListeners();
  }

  int get highScore => stat(StatKeys.bestScore);
}
