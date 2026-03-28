// Enums for fact categorisation and lifecycle status.
//
// These mirror the string values stored in the `facts` SQLite table and
// provide type-safe helpers for the rest of the app.

enum FactCategory {
  preference,
  relationship,
  habit,
  opinion,
  goal,
  biographical,
  skill;

  String get displayName {
    switch (this) {
      case preference:
        return 'Preference';
      case relationship:
        return 'Relationship';
      case habit:
        return 'Habit';
      case opinion:
        return 'Opinion';
      case goal:
        return 'Goal';
      case biographical:
        return 'About Me';
      case skill:
        return 'Skill';
    }
  }

  static FactCategory fromString(String value) {
    return FactCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FactCategory.biographical,
    );
  }
}

enum FactStatus {
  pending,
  confirmed,
  rejected;

  static FactStatus fromString(String value) {
    return FactStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FactStatus.pending,
    );
  }
}
