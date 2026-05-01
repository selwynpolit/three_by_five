import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CardLayoutMode { grid, scattered, canvas }

final cardLayoutModeProvider =
    StateProvider<CardLayoutMode>((ref) => CardLayoutMode.grid);

final cardCanvasPositionsProvider =
    NotifierProvider<CardCanvasPositionsNotifier, Map<String, Offset>>(
  CardCanvasPositionsNotifier.new,
);

class CardCanvasPositionsNotifier extends Notifier<Map<String, Offset>> {
  @override
  Map<String, Offset> build() => const {};

  void setPosition(String cardId, Offset offset) =>
      state = {...state, cardId: offset};
}
