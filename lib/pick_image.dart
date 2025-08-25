import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PickImagePage extends StatefulWidget {
  const PickImagePage({super.key});

  @override
  _PickImagePageState createState() => _PickImagePageState();
}

class _PickImagePageState extends State<PickImagePage> {
  YOLO? yolo;
  File? selectedImage;
  List<dynamic> results = [];
  Map<String, int> classCounts = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadYOLO();
  }

  Future<void> loadYOLO() async {
    setState(() => isLoading = true);
    yolo = YOLO(modelPath: 'yolo11n', task: YOLOTask.detect);
    await yolo!.loadModel();
    setState(() => isLoading = false);
  }

  Future<void> pickAndDetect() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        isLoading = true;
      });
      final imageBytes = await selectedImage!.readAsBytes();
      final detectionResults = await yolo!.predict(imageBytes);
      final detected = detectionResults['boxes'] ?? [];
      final Map<String, int> counts = {};
      for (var box in detected) {
        final label = box['class'] ?? 'Unknown';
        counts[label] = (counts[label] ?? 0) + 1;
      }
      setState(() {
        results = detected;
        classCounts = counts;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pick Image & Detect')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: yolo != null ? pickAndDetect : null,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            if (selectedImage != null)
              SizedBox(height: 200, child: Image.file(selectedImage!)),
            if (isLoading)
              CircularProgressIndicator()
            else ...[
              Text('Detected \\${results.length} objects'),
              if (classCounts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: classCounts.entries
                      .map((e) => Text('${e.key} = ${e.value}'))
                      .toList(),
                ),
            ],
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final detection = results[index];
                  return ListTile(
                    title: Text(detection['class'] ?? 'Unknown'),
                    subtitle: Text(
                      'Confidence: \\${(detection['confidence'] * 100).toStringAsFixed(1)}%',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}