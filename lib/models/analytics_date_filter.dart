enum AnalyticsDateFilterType {
  allTime,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  customRange,
}

class AnalyticsDateFilter {
  const AnalyticsDateFilter._({
    required this.type,
    this.customStartDate,
    this.customEndDate,
  });

  const AnalyticsDateFilter.allTime()
      : this._(type: AnalyticsDateFilterType.allTime);

  const AnalyticsDateFilter.today()
      : this._(type: AnalyticsDateFilterType.today);

  const AnalyticsDateFilter.yesterday()
      : this._(type: AnalyticsDateFilterType.yesterday);

  const AnalyticsDateFilter.thisWeek()
      : this._(type: AnalyticsDateFilterType.thisWeek);

  const AnalyticsDateFilter.thisMonth()
      : this._(type: AnalyticsDateFilterType.thisMonth);

  factory AnalyticsDateFilter.custom({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = calendarDate(startDate);
    final end = calendarDate(endDate);
    if (start.isAfter(end)) {
      throw ArgumentError('Custom range start date cannot be after end date.');
    }
    return AnalyticsDateFilter._(
      type: AnalyticsDateFilterType.customRange,
      customStartDate: start,
      customEndDate: end,
    );
  }

  final AnalyticsDateFilterType type;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  AnalyticsDateRange resolve([DateTime? now]) {
    final currentDate = calendarDate(now ?? DateTime.now());
    switch (type) {
      case AnalyticsDateFilterType.allTime:
        return const AnalyticsDateRange.allTime();
      case AnalyticsDateFilterType.today:
        return AnalyticsDateRange(
          start: currentDate,
          end: currentDate.add(const Duration(days: 1)),
        );
      case AnalyticsDateFilterType.yesterday:
        return AnalyticsDateRange(
          start: currentDate.subtract(const Duration(days: 1)),
          end: currentDate,
        );
      case AnalyticsDateFilterType.thisWeek:
        final daysSinceMonday = currentDate.weekday - DateTime.monday;
        final start = currentDate.subtract(Duration(days: daysSinceMonday));
        return AnalyticsDateRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case AnalyticsDateFilterType.thisMonth:
        final start = DateTime(currentDate.year, currentDate.month);
        final end = currentDate.month == DateTime.december
            ? DateTime(currentDate.year + 1)
            : DateTime(currentDate.year, currentDate.month + 1);
        return AnalyticsDateRange(start: start, end: end);
      case AnalyticsDateFilterType.customRange:
        final start = customStartDate!;
        return AnalyticsDateRange(
          start: start,
          end: customEndDate!.add(const Duration(days: 1)),
        );
    }
  }

  static DateTime calendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class AnalyticsDateRange {
  const AnalyticsDateRange({required this.start, required this.end});

  const AnalyticsDateRange.allTime()
      : start = null,
        end = null;

  final DateTime? start;
  final DateTime? end;

  bool get isAllTime => start == null && end == null;

  bool contains(DateTime value) {
    if (isAllTime) return true;
    final date = AnalyticsDateFilter.calendarDate(value);
    return !date.isBefore(start!) && date.isBefore(end!);
  }
}
