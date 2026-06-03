class Guide {
  const Guide({
    required this.id,
    required this.heroName,
    required this.imageUrl,
    required this.telegramUrl,
    this.assetPath,
  });

  final int? id;
  final String heroName;
  final String imageUrl;
  final String telegramUrl;
  final String? assetPath;
}
