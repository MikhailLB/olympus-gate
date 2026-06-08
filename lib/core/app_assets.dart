/// Centralized asset paths for Olympus Gate.
class AppAssets {
  AppAssets._();

  static const String _img = 'assets/images';

  // Branding
  static const String gameName = '$_img/Game_Name.webp';
  static const String logo = '$_img/Logo_1.webp';
  static const String coin = '$_img/Coin_Asset.webp';

  // Gods (characters)
  static const String zeus = '$_img/Zeus_Asset.webp';
  static const String poseidon = '$_img/Poseidon_Asset.webp';
  static const String prometheus = '$_img/Prometei_Asset.webp';
  static const String hades = '$_img/Aid_Asset.webp';

  // God backgrounds (vertical)
  static const String zeusBg = '$_img/Zeus_bg_asset.webp';
  static const String poseidonBg = '$_img/Poseidon_bg_asset.webp';
  static const String prometheusBg = '$_img/Prometei_bg_asset.webp';
  static const String hadesBg = '$_img/Aid_bg_asset.webp';

  // Gameplay objects
  static const List<String> lightnings = [
    '$_img/Lightning_01_asset.webp',
    '$_img/Lightning_02_asset.webp',
    '$_img/Lightning_03_asset.webp',
    '$_img/Lightning_04_asset.webp',
  ];
  static const List<String> rocks = [
    '$_img/Rock_01_Asset.webp',
    '$_img/Rock_02_Asset.webp',
  ];

  // Full-screen art (vertical)
  static const String loadingVertical = '$_img/Vertical_Loading_Screen.webp';

  /// Every asset that should be precached before gameplay starts.
  static const List<String> all = [
    gameName,
    logo,
    coin,
    zeus,
    poseidon,
    prometheus,
    hades,
    zeusBg,
    poseidonBg,
    prometheusBg,
    hadesBg,
    ...lightnings,
    ...rocks,
    loadingVertical,
  ];
}
