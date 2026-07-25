/// Overview statistics from user_flight_stats view.
class OverviewStats {
  final int totalFlights;
  final double totalKm;
  final double totalHours;

  OverviewStats({
    required this.totalFlights,
    required this.totalKm,
    required this.totalHours,
  });

  factory OverviewStats.fromJson(Map<String, dynamic> json) {
    return OverviewStats(
      totalFlights: json['total_flights'] as int? ?? 0,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0.0,
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory OverviewStats.empty() {
    return OverviewStats(
      totalFlights: 0,
      totalKm: 0.0,
      totalHours: 0.0,
    );
  }
}

/// Mileage percentile scope type.
enum PercentileScope {
  global,
  national,
  noData('no_data');

  final String? value;
  const PercentileScope([this.value]);

  String get displayName {
    switch (this) {
      case PercentileScope.global:
        return 'Global';
      case PercentileScope.national:
        return 'National';
      case PercentileScope.noData:
        return 'Insufficient Data';
    }
  }

  static PercentileScope fromString(String? value) {
    switch (value) {
      case 'global':
        return PercentileScope.global;
      case 'national':
        return PercentileScope.national;
      case 'no_data':
      default:
        return PercentileScope.noData;
    }
  }
}

/// Mileage percentile data from my_mileage_percentile() RPC.
class MileagePercentile {
  final double percentile;
  final PercentileScope scope;

  MileagePercentile({
    required this.percentile,
    required this.scope,
  });

  factory MileagePercentile.fromJson(Map<String, dynamic> json) {
    return MileagePercentile(
      percentile: (json['percentile'] as num?)?.toDouble() ?? 0.0,
      scope: PercentileScope.fromString(json['scope'] as String?),
    );
  }

  factory MileagePercentile.empty() {
    return MileagePercentile(
      percentile: 0.0,
      scope: PercentileScope.noData,
    );
  }
}
