enum InsightType {
  revenue,
  topProduct,
  topCategory,
  profitMargin,
  customer,
  salesMilestone,
}

enum InsightSeverity { info, positive, warning }

class Insight {
  const Insight({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.value,
    this.comparisonValue,
    this.relatedEntityName,
  });

  final InsightType type;
  final String title;
  final String message;
  final InsightSeverity severity;
  final double? value;
  final double? comparisonValue;
  final String? relatedEntityName;
}
