enum AlertType { outOfStock, lowStock, lowProfitMargin }

enum AlertSeverity { critical, warning }

class Alert {
  const Alert({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.relatedEntityName,
    this.value,
  });

  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? relatedEntityName;
  final double? value;
}
