/// Weekday keys for outfit planner (matches Laravel saved_outfits.planned_day).
class OutfitPlannerDays {
  OutfitPlannerDays._();

  static const keys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const labels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  /// Current weekday key in local time.
  static String todayKey() {
    return keys[DateTime.now().weekday - 1];
  }
}
