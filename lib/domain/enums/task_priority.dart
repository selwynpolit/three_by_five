enum TaskPriority {
  high,
  normal,
  low;

  static TaskPriority fromString(String value) =>
      TaskPriority.values.byName(value);
}
