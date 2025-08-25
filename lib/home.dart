import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'live_detection.dart';
import 'pick_image.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Positioned(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                      'assets/logo_agrinas.png',
                      height: 120,
                      ),
                      const SizedBox(height: 16),
                      Text(
                      'Deteksi Kematangan Kelapa Sawit',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32), // Colors.green[800] as a constant
                      ),
                      ),
                    ],
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraDetectionScreen()),
                    );
                    if (kDebugMode) {
                      print('Deteksi Langsung');
                    }
                  },
                  child: const Text('Deteksi Langsung'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PickImagePage()),
                    );
                    if (kDebugMode) {
                      print('Pilih Gambar');
                    }
                  },
                  child: const Text('Pilih Gambar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
