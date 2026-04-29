// macOS speech-to-text wrapper. Implemented in Session 9.
class VoiceService {
  bool get isAvailable => false;
  Future<void> start({required void Function(String words) onResult}) async {}
  Future<void> stop() async {}
}
