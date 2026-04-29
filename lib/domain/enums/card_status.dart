enum CardStatus {
  active,
  archived,
  expanded;

  static CardStatus fromString(String value) =>
      CardStatus.values.byName(value);
}
