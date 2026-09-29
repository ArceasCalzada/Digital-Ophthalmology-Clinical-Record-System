import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';

void main() {
  // Tuesday, Sep 29 2026, late in the evening.
  final now = DateTime(2026, 9, 29, 23, 30);

  test('formats weekday, month, day and distance from today', () {
    expect(formatScheduleDate(DateTime(2026, 9, 29, 8), now: now), 'Tue, Sep 29 (Today)');
    expect(formatScheduleDate(DateTime(2026, 9, 30, 11), now: now), 'Wed, Sep 30 (Tomorrow)');
    expect(formatScheduleDate(DateTime(2026, 10, 1, 10), now: now), 'Thu, Oct 1 (2 days from now)');
    expect(formatScheduleDate(DateTime(2026, 9, 28, 10), now: now), 'Mon, Sep 28 (Yesterday)');
    expect(formatScheduleDate(DateTime(2026, 9, 25, 10), now: now), 'Fri, Sep 25 (4 days ago)');
  });

  test('after the first week it counts weeks, then months, then years', () {
    String f(DateTime d) => formatScheduleDate(d, now: now);
    expect(f(DateTime(2026, 10, 5)), 'Mon, Oct 5 (6 days from now)');
    expect(f(DateTime(2026, 10, 6)), 'Tue, Oct 6 (1 week from now)');
    expect(f(DateTime(2026, 10, 13)), 'Tue, Oct 13 (2 weeks from now)');
    expect(f(DateTime(2026, 10, 28)), 'Wed, Oct 28 (4 weeks from now)');
    expect(f(DateTime(2026, 10, 29)), 'Thu, Oct 29 (1 month from now)');
    expect(f(DateTime(2026, 11, 29)), 'Sun, Nov 29 (2 months from now)');
    expect(f(DateTime(2026, 9, 23)), 'Wed, Sep 23 (6 days ago)');
    expect(f(DateTime(2026, 9, 22)), 'Tue, Sep 22 (1 week ago)');
    expect(f(DateTime(2026, 9, 15)), 'Tue, Sep 15 (2 weeks ago)');
    expect(f(DateTime(2026, 8, 29)), 'Sat, Aug 29 (1 month ago)');
  });

  test('the year only appears when it is not the current year', () {
    expect(formatScheduleDate(DateTime(2026, 12, 25), now: now), 'Fri, Dec 25 (2 months from now)');
    expect(formatScheduleDate(DateTime(2027, 1, 7), now: now), 'Thu, Jan 7, 2027 (3 months from now)');
    expect(formatScheduleDate(DateTime(2027, 9, 29), now: now), 'Wed, Sep 29, 2027 (1 year from now)');
    expect(formatScheduleDate(DateTime(2025, 9, 29), now: now), 'Mon, Sep 29, 2025 (1 year ago)');
    expect(formatScheduleDate(DateTime(2027, 1, 7), now: now, long: true), 'Thursday, Jan. 7, 2027 (3 months from now)');
  });

  test('long form spells out the weekday and abbreviates the month with a period', () {
    expect(formatScheduleDate(DateTime(2026, 9, 29, 8), now: now, long: true), 'Tuesday, Sep. 29 (Today)');
    expect(formatScheduleDate(DateTime(2026, 11, 16), now: DateTime(2026, 11, 16), long: true), 'Monday, Nov. 16 (Today)');
    expect(formatScheduleDate(DateTime(2026, 5, 3), now: DateTime(2026, 5, 1), long: true), 'Sunday, May 3 (2 days from now)');
  });
}
