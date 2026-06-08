/// Stat keys tracked across the player's whole career.
class StatKeys {
  StatKeys._();
  static const String gamesPlayed = 'games_played';
  static const String totalCoins = 'total_coins';
  static const String wrathUnleashed = 'wrath_unleashed';
  static const String totalScore = 'total_score';
  static const String rocksSmashed = 'rocks_smashed';
  static const String bestScore = 'best_score';
  static const String bestCombo = 'best_combo';
}

/// A career achievement that grants gold once its target is reached.
class Mission {
  final String id;
  final String title;
  final String description;
  final String statKey;
  final int target;
  final int reward;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.statKey,
    required this.target,
    required this.reward,
  });

  static const List<Mission> all = [
    Mission(
      id: 'first_steps',
      title: 'First Ascension',
      description: 'Play your first run at the gate.',
      statKey: StatKeys.gamesPlayed,
      target: 1,
      reward: 150,
    ),
    Mission(
      id: 'coin_hoarder',
      title: 'Coin Hoarder',
      description: 'Collect 500 gold across all runs.',
      statKey: StatKeys.totalCoins,
      target: 500,
      reward: 300,
    ),
    Mission(
      id: 'storm_caller',
      title: 'Storm Caller',
      description: 'Unleash the Wrath of Olympus 10 times.',
      statKey: StatKeys.wrathUnleashed,
      target: 10,
      reward: 400,
    ),
    Mission(
      id: 'survivor',
      title: 'Favoured by Fate',
      description: 'Score 1000 points in a single run.',
      statKey: StatKeys.bestScore,
      target: 1000,
      reward: 500,
    ),
    Mission(
      id: 'rock_breaker',
      title: 'Boulder Breaker',
      description: 'Smash 50 rocks with your Wrath.',
      statKey: StatKeys.rocksSmashed,
      target: 50,
      reward: 450,
    ),
    Mission(
      id: 'marathon',
      title: 'Eternal Champion',
      description: 'Play 25 runs at the gate.',
      statKey: StatKeys.gamesPlayed,
      target: 25,
      reward: 700,
    ),
    Mission(
      id: 'rich_god',
      title: 'Rich as a God',
      description: 'Collect 5000 gold across all runs.',
      statKey: StatKeys.totalCoins,
      target: 5000,
      reward: 1200,
    ),
    Mission(
      id: 'combo_master',
      title: 'Combo Master',
      description: 'Reach a x15 coin combo.',
      statKey: StatKeys.bestCombo,
      target: 15,
      reward: 600,
    ),
    Mission(
      id: 'untouchable',
      title: 'Untouchable',
      description: 'Score 3000 points in a single run.',
      statKey: StatKeys.bestScore,
      target: 3000,
      reward: 1500,
    ),
  ];
}
