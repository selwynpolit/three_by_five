// Phase 2: Google Calendar read integration. Interface defined here; not implemented yet.
abstract interface class CalendarService {
  Future<void> authenticate();
  Future<void> syncEvents();
}
