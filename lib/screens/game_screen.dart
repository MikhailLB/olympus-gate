import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../game/falling_object.dart';
import '../models/god.dart';
import '../services/game_storage.dart';
import '../widgets/coin_pill.dart';
import '../widgets/olympus_button.dart';

enum GamePhase { countdown, playing, paused, gameOver }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  late God _god;
  late GameStorage _storage;
  bool _initialized = false;

  // Arena dimensions (set from LayoutBuilder).
  Size _size = Size.zero;
  static const double _playerWidth = 104;
  static const double _playerHeight = 150;
  double get _playerY => _size.height - 120; // center y of player sprite

  // Player state
  double _playerX = 0;
  double _targetX = 0;

  // Game state
  GamePhase _phase = GamePhase.countdown;
  double _countdown = 3.0;
  Duration _lastElapsed = Duration.zero;
  double _elapsed = 0; // seconds spent playing
  double _spawnTimer = 0;

  int _hearts = 3;
  int _maxHearts = 3;
  int _score = 0;
  int _goldEarned = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _wrathUses = 0;
  int _rocksSmashed = 0;
  double _wrath = 0; // 0..1
  double _invincible = 0; // seconds of invulnerability remaining
  bool _revived = false;
  double _shake = 0; // screen-shake intensity
  double _flash = 0; // wrath flash overlay 0..1

  final List<FallingObject> _objects = [];
  final List<FloatingText> _floats = [];

  bool _isRecordRun = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _storage = AppScope.read(context);
      _god = _storage.selectedGod;
      _maxHearts = _god.baseHearts;
      _hearts = _maxHearts;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // --- Game loop ----------------------------------------------------------
  void _startLoop() {
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final double dt =
        (_lastElapsed == Duration.zero)
            ? 0
            : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    final double step = dt.clamp(0.0, 0.05); // guard against long frames

    switch (_phase) {
      case GamePhase.countdown:
        _countdown -= step;
        if (_countdown <= 0) {
          _phase = GamePhase.playing;
        }
        break;
      case GamePhase.playing:
        _updatePlaying(step);
        break;
      case GamePhase.paused:
      case GamePhase.gameOver:
        break;
    }
    if (mounted) setState(() {});
  }

  void _updatePlaying(double dt) {
    _elapsed += dt;

    // Smoothly move the player toward the target touch position.
    _playerX += (_targetX - _playerX) * math.min(1, dt * 16);

    if (_invincible > 0) _invincible = math.max(0, _invincible - dt);
    if (_shake > 0) _shake = math.max(0, _shake - dt * 3);
    if (_flash > 0) _flash = math.max(0, _flash - dt * 2);

    // Spawning with rising difficulty.
    final double interval =
        math.max(0.42, 0.95 - _elapsed * 0.011);
    _spawnTimer += dt;
    if (_spawnTimer >= interval) {
      _spawnTimer = 0;
      _spawn();
    }

    // Update objects + collisions.
    for (final o in _objects) {
      o.update(dt);
      if (o.collected) continue;
      if (_overlapsPlayer(o)) {
        _handleCatch(o);
      }
    }

    // Remove off-screen / collected objects, resetting combo on missed coins.
    _objects.removeWhere((o) {
      if (o.collected) return true;
      if (o.y - o.radius > _size.height) {
        if (o.type == FallingType.coin) _combo = 0;
        return true;
      }
      return false;
    });

    for (final f in _floats) {
      f.update(dt);
    }
    _floats.removeWhere((f) => f.dead);
  }

  void _spawn() {
    // Difficulty shifts the mix toward more rocks over time.
    final double rockChance = math.min(0.45, 0.26 + _elapsed * 0.0016);
    final double r = _rng.nextDouble();
    FallingType type;
    if (r < rockChance) {
      type = FallingType.rock;
    } else if (r < rockChance + 0.16) {
      type = FallingType.lightning;
    } else {
      type = FallingType.coin;
    }

    final double baseSpeed = 215 + _elapsed * 6.5;
    final double speed = (baseSpeed + _rng.nextDouble() * 70)
        .clamp(180.0, 640.0);
    final double size = switch (type) {
      FallingType.coin => 52,
      FallingType.lightning => 56,
      FallingType.rock => 66 + _rng.nextDouble() * 26,
    };
    final double margin = size / 2 + 8;
    final double x = margin + _rng.nextDouble() * (_size.width - margin * 2);

    _objects.add(
      FallingObject(
        type: type,
        x: x,
        y: -size,
        size: size,
        speed: speed,
        asset: FallingObject.assetFor(type, _rng.nextInt(4)),
        spinSpeed: type == FallingType.rock
            ? (_rng.nextDouble() - 0.5) * 2.2
            : 0,
        drift: type == FallingType.coin
            ? (_rng.nextDouble() - 0.5) * 40
            : 0,
      ),
    );
  }

  bool _overlapsPlayer(FallingObject o) {
    final double dx = (o.x - _playerX).abs();
    final double dy = (o.y - (_playerY - 10)).abs();
    return dx < (_playerWidth * 0.36 + o.radius * 0.6) &&
        dy < (_playerHeight * 0.34 + o.radius * 0.6);
  }

  void _handleCatch(FallingObject o) {
    switch (o.type) {
      case FallingType.coin:
        o.collected = true;
        _combo++;
        _bestCombo = math.max(_bestCombo, _combo);
        final int gold = _god.coinMultiplier.round();
        _goldEarned += gold;
        final int pts = 10 * (1 + _combo ~/ 5);
        _score += pts;
        _addFloat('+$pts', o.x, o.y, AppColors.goldLight);
        _haptic(light: true);
        break;
      case FallingType.lightning:
        o.collected = true;
        _wrath = math.min(1.0, _wrath + 0.14 * _god.wrathGain);
        _score += 5;
        _addFloat('+5', o.x, o.y, AppColors.skyBlue);
        _haptic(light: true);
        break;
      case FallingType.rock:
        if (_invincible > 0) {
          // Smash through while empowered.
          o.collected = true;
          _rocksSmashed++;
          _score += 25;
          _addFloat('+25', o.x, o.y, AppColors.danger);
        } else {
          o.collected = true;
          _combo = 0;
          _shake = 1.0;
          _invincible = 1.1; // brief mercy window
          _haptic(light: false);
          _hearts--;
          if (_hearts <= 0) {
            _onHeartsEmpty();
          }
        }
        break;
    }
  }

  void _onHeartsEmpty() {
    if (_god.reviveOnce && !_revived) {
      _revived = true;
      _hearts = _maxHearts;
      _invincible = 2.5;
      _flash = 1.0;
      _addFloat('REVIVED!', _playerX, _playerY - 90, _god.accent);
      return;
    }
    _gameOver();
  }

  void _addFloat(String text, double x, double y, Color color) {
    _floats.add(FloatingText(text: text, x: x, y: y, color: color));
  }

  void _haptic({required bool light}) {
    if (!_storage.hapticsOn) return;
    if (light) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  // --- Wrath --------------------------------------------------------------
  void _unleashWrath() {
    if (_wrath < 1.0 || _phase != GamePhase.playing) return;
    _wrath = 0;
    _wrathUses++;
    _invincible = math.max(_invincible, 4.0);
    _flash = 1.0;
    _haptic(light: false);
    // Smash every rock currently on screen.
    for (final o in _objects) {
      if (o.type == FallingType.rock && !o.collected) {
        o.collected = true;
        _rocksSmashed++;
        _score += 25;
      }
    }
    // Reward shower of coins.
    final int bonus = 60;
    _goldEarned += bonus;
    _score += 150;
    _addFloat('WRATH! +$bonus', _size.width / 2, _playerY - 140,
        AppColors.goldLight);
  }

  // --- Lifecycle ----------------------------------------------------------
  void _gameOver() {
    _phase = GamePhase.gameOver;
    _isRecordRun = _score > _storage.highScore;
    _storage.recordRunResult(
      score: _score,
      coinsEarned: _goldEarned,
      wrathUsed: _wrathUses,
      rocksSmashed: _rocksSmashed,
      bestCombo: _bestCombo,
    );
  }

  void _pause() {
    if (_phase == GamePhase.playing) {
      setState(() => _phase = GamePhase.paused);
    }
  }

  void _resume() {
    if (_phase == GamePhase.paused) {
      setState(() => _phase = GamePhase.playing);
    }
  }

  void _restart() {
    setState(() {
      _objects.clear();
      _floats.clear();
      _phase = GamePhase.countdown;
      _countdown = 3.0;
      _elapsed = 0;
      _spawnTimer = 0;
      _maxHearts = _god.baseHearts;
      _hearts = _maxHearts;
      _score = 0;
      _goldEarned = 0;
      _combo = 0;
      _bestCombo = 0;
      _wrathUses = 0;
      _rocksSmashed = 0;
      _wrath = 0;
      _invincible = 0;
      _revived = false;
      _shake = 0;
      _flash = 0;
      _isRecordRun = false;
    });
  }

  void _onPointer(Offset local) {
    if (_phase != GamePhase.playing) return;
    final double half = _playerWidth / 2;
    _targetX = local.dx.clamp(half, _size.width - half);
  }

  // --- Build --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_size == Size.zero) {
            _size = newSize;
            _playerX = newSize.width / 2;
            _targetX = _playerX;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _startLoop());
          } else {
            _size = newSize;
          }

          final double shakeX =
              _shake > 0 ? (_rng.nextDouble() - 0.5) * 18 * _shake : 0;
          final double shakeY =
              _shake > 0 ? (_rng.nextDouble() - 0.5) * 18 * _shake : 0;

          return Listener(
            onPointerDown: (e) => _onPointer(e.localPosition),
            onPointerMove: (e) => _onPointer(e.localPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(shakeX, shakeY),
                  child: _arena(),
                ),
                // Wrath flash overlay.
                IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.6 * _flash),
                  ),
                ),
                _hud(),
                if (_phase == GamePhase.countdown) _countdownOverlay(),
                if (_phase == GamePhase.paused) _pauseOverlay(),
                if (_phase == GamePhase.gameOver) _gameOverOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _arena() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_god.background, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        // Falling objects.
        ..._objects.map(_buildObject),
        // Floating score popups.
        ..._floats.map(_buildFloat),
        // Player.
        _buildPlayer(),
      ],
    );
  }

  Widget _buildObject(FallingObject o) {
    return Positioned(
      left: o.x - o.radius,
      top: o.y - o.radius,
      width: o.size,
      height: o.size,
      child: Transform.rotate(
        angle: o.spin,
        child: Image.asset(o.asset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildFloat(FloatingText f) {
    return Positioned(
      left: f.x - 60,
      top: f.y,
      width: 120,
      child: Opacity(
        opacity: (1 - f.life).clamp(0.0, 1.0),
        child: Text(
          f.text,
          textAlign: TextAlign.center,
          style: AppTheme.title(20, color: f.color),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final bool blink =
        _invincible > 0 && (_invincible * 12).floor().isEven;
    return Positioned(
      left: _playerX - _playerWidth / 2,
      top: _playerY - _playerHeight / 2,
      width: _playerWidth,
      height: _playerHeight,
      child: Opacity(
        opacity: blink ? 0.45 : 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Accent glow.
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _god.accent.withValues(alpha: _invincible > 0 ? 0.6 : 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Image.asset(_god.asset, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  // --- HUD ----------------------------------------------------------------
  Widget _hud() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hearts > 0 ? _heartsRow() : const SizedBox(),
                const Spacer(),
                Column(
                  children: [
                    _scorePill(),
                    const SizedBox(height: 6),
                    CoinPill(amount: _goldEarned, fontSize: 15),
                  ],
                ),
                const SizedBox(width: 10),
                OlympusIconButton(
                  icon: Icons.pause,
                  size: 42,
                  onTap: _pause,
                ),
              ],
            ),
          ),
          if (_combo >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'COMBO x${1 + _combo ~/ 5}',
                style: AppTheme.title(22, color: AppColors.goldLight),
              ),
            ),
          const Spacer(),
          _wrathBar(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _heartsRow() {
    return Row(
      children: List.generate(_maxHearts, (i) {
        final filled = i < _hearts;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            color: filled ? AppColors.heart : Colors.white38,
            size: 28,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        );
      }),
    );
  }

  Widget _scorePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stormBlue, width: 1.5),
      ),
      child: Text('$_score', style: AppTheme.title(22)),
    );
  }

  Widget _wrathBar() {
    final bool ready = _wrath >= 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.skyBlue, width: 1.5),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _wrath.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.skyBlue, AppColors.stormBlue],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      ready ? 'WRATH READY' : 'WRATH OF OLYMPUS',
                      style: AppTheme.body(12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: ready ? _unleashWrath : null,
            child: AnimatedScale(
              scale: ready ? 1.0 : 0.85,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: ready
                        ? const [AppColors.goldLight, AppColors.goldDark]
                        : [Colors.grey.shade700, Colors.grey.shade900],
                  ),
                  border: Border.all(
                    color: ready ? Colors.white : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: ready
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.8),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.bolt,
                  color: ready ? const Color(0xFF3A2706) : Colors.white54,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Overlays -----------------------------------------------------------
  Widget _countdownOverlay() {
    final int n = _countdown.ceil();
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Text(
        n > 0 ? '$n' : 'GO',
        style: AppTheme.title(96, color: AppColors.goldLight),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PAUSED', style: AppTheme.title(40)),
          const SizedBox(height: 30),
          OlympusButton(
            label: 'RESUME',
            width: 220,
            icon: Icons.play_arrow,
            onTap: _resume,
          ),
          const SizedBox(height: 14),
          OlympusButton(
            label: 'QUIT',
            width: 220,
            primary: false,
            icon: Icons.home,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _gameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DEFEATED', style: AppTheme.title(40, color: AppColors.danger)),
            const SizedBox(height: 16),
            if (_isRecordRun)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text('NEW RECORD!',
                    style: AppTheme.title(18, color: AppColors.goldLight)),
              ),
            _resultRow('Score', '$_score'),
            _resultRow('Best', '${_storage.highScore}'),
            _resultRow('Combo', 'x${1 + _bestCombo ~/ 5}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppAssets.coin, width: 30, height: 30),
                const SizedBox(width: 8),
                Text('+$_goldEarned Gold',
                    style: AppTheme.title(22, color: AppColors.goldLight)),
              ],
            ),
            const SizedBox(height: 28),
            OlympusButton(
              label: 'PLAY AGAIN',
              width: 240,
              icon: Icons.refresh,
              onTap: _restart,
            ),
            const SizedBox(height: 14),
            OlympusButton(
              label: 'MENU',
              width: 240,
              primary: false,
              icon: Icons.home,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.body(18, color: Colors.white70)),
          Text(value, style: AppTheme.title(20)),
        ],
      ),
    );
  }
}
