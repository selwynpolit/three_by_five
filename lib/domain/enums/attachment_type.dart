enum AttachmentType {
  image,
  link,
  emailClip;

  static AttachmentType fromString(String value) =>
      AttachmentType.values.byName(value);
}
