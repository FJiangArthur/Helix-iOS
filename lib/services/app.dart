import 'evenai.dart';

class App {
  static App? _instance;
  static App get get => _instance ??= App._();

  App._();

  // Exit all features by receiving [0xf5 0]
  void exitAll({bool isNeedBackHome = true}) async {
    if (EvenAI.isEvenAIOpen.value) {
      await EvenAI.get.stopEvenAIByOS();
    }
  }
}