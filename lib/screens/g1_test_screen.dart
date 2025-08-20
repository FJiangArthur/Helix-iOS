import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_helix/screens/even_features_screen.dart';
import '../ble_manager.dart';
import 'package:get/get.dart';

/// Simple test screen for G1 glasses connection and text sending
class G1TestScreen extends StatefulWidget {
  const G1TestScreen({super.key});

  @override
  State<G1TestScreen> createState() => _G1TestScreenState();
}

class _G1TestScreenState extends State<G1TestScreen> {
  Timer? scanTimer;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    BleManager.get().setMethodCallHandler();
    BleManager.get().startListening();
    BleManager.get().onStatusChanged = _refreshPage;
  }

  void _refreshPage() => setState(() {});

  Future<void> _startScan() async {
    setState(() => isScanning = true);
    await BleManager.get().startScan();
    scanTimer?.cancel();
    scanTimer = Timer(15.seconds, () {
      // todo
      _stopScan();
    });
  }

  Future<void> _stopScan() async {
    if (isScanning) {
      await BleManager.get().stopScan();
      setState(() => isScanning = false);
    }
  }

  Widget blePairedList() => Expanded(
    child: ListView.separated(
      separatorBuilder: (context, index) => const SizedBox(height: 5),
      itemCount: BleManager.get().getPairedGlasses().length,
      itemBuilder: (context, index) {
        final glasses = BleManager.get().getPairedGlasses()[index];
        return GestureDetector(
          onTap: () async {
            String channelNumber = glasses['channelNumber']!;
            await BleManager.get().connectToGlasses("Pair_$channelNumber");
            _refreshPage();
          },
          child: Container(
            height: 72,
            padding: const EdgeInsets.only(left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pair: ${glasses['channelNumber']}'),
                    Text(
                      'Left: ${glasses['leftDeviceName']} \nRight: ${glasses['rightDeviceName']}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              if (BleManager.get().getConnectionStatus() == 'Not connected') {
                _startScan();
              }
            },
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text(
                BleManager.get().getConnectionStatus(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (BleManager.get().getConnectionStatus() == 'Not connected')
            blePairedList(),
          if (BleManager.get().isConnected)
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  print("To AI History List...");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FeaturesPage(),
                    ),
                  );
                },
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const Text(
                    "Tap to access Even Features",
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

  @override
  void dispose() {
    scanTimer?.cancel();
    isScanning = false;
    BleManager.get().onStatusChanged = null;
    super.dispose();
  }
}
