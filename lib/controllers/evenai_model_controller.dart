import '../models/evenai_model.dart';
import 'package:get/get.dart';

class EvenaiModelController extends GetxController {
  var items = <EvenaiModel>[].obs;
  var selectedIndex = Rxn<int>();

  @override
  void onInit() {
    super.onInit();
    // Add some test data for development
    _addTestData();
  }

  void _addTestData() {
    // Add sample AI conversation items for testing
    addItem(
      "Meeting with Tom about Q4 strategy",
      "Key points discussed:\n• Revenue targets for Q4\n• New product launch timeline\n• Marketing budget allocation\n• Team restructuring plans\n\nAction items:\n• Schedule follow-up with marketing team\n• Review budget proposals by Friday\n• Prepare presentation for board meeting"
    );
    
    addItem(
      "Coffee chat with Sarah",
      "Casual conversation covering:\n• Weekend hiking trip\n• New restaurant recommendations\n• Book club discussion\n• Work-life balance tips\n\nPersonal notes:\n• Sarah recommended 'Atomic Habits' book\n• Suggested trying the new sushi place downtown\n• Planning joint hiking trip next month"
    );
    
    addItem(
      "Conference call with London office", 
      "Topics covered:\n• Project timeline synchronization\n• Resource allocation between offices\n• Cross-team collaboration improvements\n• Quarterly review preparation\n\nDecisions made:\n• Weekly sync calls every Tuesday\n• Shared project management tool implementation\n• Q4 review scheduled for December 15th"
    );
  }

  void addItem(String title, String content) {
    final newItem = EvenaiModel(title: title, content: content, createdTime: DateTime.now());
    items.insert(0, newItem);
  }

  void removeItem(int index) {
    items.removeAt(index);
    if (selectedIndex.value == index) {
      selectedIndex.value = null;
    } else if (selectedIndex.value != null && selectedIndex.value! > index) {
      selectedIndex.value = selectedIndex.value! - 1;
    }
  }

  void clearItems() {
    items.clear();
    selectedIndex.value = null;
  }

  void selectItem(int index) {
    selectedIndex.value = index;
  }

  void deselectItem() {
    selectedIndex.value = null;
  }
}