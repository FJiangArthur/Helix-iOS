import 'package:flutter/material.dart';
import '../controllers/evenai_model_controller.dart';
import '../services/evenai.dart';
import 'package:get/get.dart';

/// AI conversation history screen matching Even official implementation
class EvenAIHistoryScreen extends StatefulWidget {
  const EvenAIHistoryScreen({super.key});

  @override
  State<EvenAIHistoryScreen> createState() => _EvenAIHistoryScreenState();
}

class _EvenAIHistoryScreenState extends State<EvenAIHistoryScreen> {
  late EvenaiModelController controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller if not already initialized
    try {
      controller = Get.find<EvenaiModelController>();
    } catch (e) {
      // If controller doesn't exist, create it
      controller = Get.put(EvenaiModelController());
    }

    print("controller.items--------${controller.items.length}");
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: const Text('History',
            style: TextStyle(fontSize: 20)),
    ),
    body: Obx(() {
      if (controller.items.isEmpty && !EvenAI.isEvenAISyncing.value) {
        return const Center(
          child: Text(
            "Press and hold left TouchBar to engage Even AI.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        );
      } else {

          return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: controller.items.length,
                      itemBuilder: (context, index) {
                      return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (controller.selectedIndex.value ==
                                    index) {
                                  controller.deselectItem();
                                } else {
                                  controller.selectItem(index);
                                }
                              });
                            },
                            child: controller.selectedIndex.value == index
                                    ? buildItemDetail(index)
                                    : buildItem(index),
                          );
                      },
                    ),
                  ),
                ],
              ),
            );
      }
    }),
  );


  Widget buildItem(int index) {
    final item = controller.items[index];
    return Container(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF991).withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
      ),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          item.title,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget buildItemDetail(int index) {
    final item = controller.items[index];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF991).withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
      ),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(16),
            child: Text(item.title,
                     style: const TextStyle(fontSize: 20),
                ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.content,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(height: 16)
        ],
      ),
    );
  }
}