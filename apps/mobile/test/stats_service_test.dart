import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/services/stats_service.dart';

void main() {
  test('year range extends from earliest flight through current year', () {
    final years = StatsService.yearRangeFromRows([
      {'departure_time': '2022-04-01T23:00:00Z'}
    ], DateTime.utc(2026, 7, 25));
    expect(years, [2022, 2023, 2024, 2025, 2026]);
  });

  test('new users still receive the current year', () {
    expect(StatsService.yearRangeFromRows([], DateTime.utc(2026)), [2026]);
  });

  test('daily counts use UTC departure dates', () {
    final counts = StatsService.countDays([
      {'departure_time': '2026-07-02T00:30:00Z'},
      {'departure_time': '2026-07-02T22:30:00Z'},
    ], 2026, 7);
    expect(counts[2], 2);
    expect(counts[1], 0);
  });
}
