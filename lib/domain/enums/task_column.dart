enum TaskColumn {
  now,
  later;

  static TaskColumn fromString(String value) =>
      TaskColumn.values.byName(value);
}
