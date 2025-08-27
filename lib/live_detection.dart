import 'package:ultralytics_yolo/yolo_view.dart';
import 'dart:io';
//import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_streaming_config.dart';
import 'package:flutter/services.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  late YOLOViewController controller;
  final GlobalKey _repaintKey = GlobalKey();
  late YOLOStreamingConfig _streamingConfig;
  List<dynamic> currentResults = [];
  double fps = 0.0;
  double processingTimeMs = 0.0;
  Uint8List? _lastFrameBytes;
  Map<int, int> classCounts = {};
  final List<String> classLabels = [
    'Janjang kosong', // 0
    'Kurang masak', // 1
    'TBS abnormal', // 2
    'TBS masak', // 3
    'TBS mentah', // 4
    'Terlalu masak', // 5
  ];
  // (removed unused _lastResultTimestampMs)
  // timestamps (ms) of recent onResult callbacks for local FPS calculation
  final List<int> _frameTimestampsMs = [];
  // smoothing factor for displayed FPS (0..1)
  final double _fpsSmoothing = 0.2;

  @override
  void initState() {
    super.initState();
    controller = YOLOViewController();
    _streamingConfig = YOLOStreamingConfig(
      includeDetections: true,
      includeFps: true,
      includeProcessingTimeMs: true,
      includeOriginalImage: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera view with YOLO processing
          RepaintBoundary(
            key: _repaintKey,
            child: YOLOView(
              modelPath: 'yolo11n',
              task: YOLOTask.detect,
              streamingConfig: _streamingConfig,
              showNativeUI: true,
              controller: controller,
              onResult: (dynamic results) {
                if (kDebugMode) {
                  try {
                    print(
                      'onResult called - runtimeType=${results.runtimeType}',
                    );
                    if (results is List) {
                      print('onResult list length=${results.length}');
                      if (results.isNotEmpty)
                        print('onResult[0]=${results[0]}');
                    } else if (results is Map) {
                      print('onResult map keys=${results.keys}');
                    } else {
                      print('onResult value=$results');
                    }
                  } catch (e) {
                    print('onResult debug print failed: $e');
                  }
                }
                // compute local FPS using sliding window of onResult timestamps
                final int nowMs = DateTime.now().millisecondsSinceEpoch;
                _frameTimestampsMs.add(nowMs);
                // remove timestamps older than 1 second
                _frameTimestampsMs.removeWhere((t) => t < nowMs - 1000);
                final double instantFps = _frameTimestampsMs.length.toDouble();

                // normalize results to a List<dynamic> so we can count them reliably
                List<dynamic> parsed = [];
                try {
                  if (results is List) {
                    parsed = List<dynamic>.from(results);
                  } else if (results is Map &&
                      results.containsKey('boxes') &&
                      results['boxes'] is List) {
                    parsed = List<dynamic>.from(results['boxes']);
                  } else if (results is Map &&
                      results.containsKey('detections') &&
                      results['detections'] is List) {
                    parsed = List<dynamic>.from(results['detections']);
                  } else if (results is Iterable) {
                    parsed = List<dynamic>.from(results);
                  } else {
                    // single result -> wrap
                    parsed = [results];
                  }
                } catch (e) {
                  parsed = [results];
                }

                if (kDebugMode) {
                  try {
                    print('parsed results length=${parsed.length}');
                    for (var i = 0; i < parsed.length && i < 3; i++) {
                      final e = parsed[i];
                      if (e is YOLOResult) {
                        print(
                          'parsed[$i] class=${e.className} conf=${e.confidence}',
                        );
                      } else if (e is Map) {
                        print('parsed[$i] map keys=${e.keys}');
                      } else {
                        print('parsed[$i] value=$e');
                      }
                    }
                  } catch (e) {
                    print('parsed debug failed: $e');
                  }
                }

                if (!mounted) return;
                setState(() {
                  currentResults = parsed;
                  // compute counts per class index
                  final Map<int, int> counts = {};
                  for (var item in parsed) {
                    int? idx;
                    if (item is YOLOResult) {
                      idx = item.classIndex;
                    } else if (item is Map && item.containsKey('classIndex')) {
                      try {
                        final v = item['classIndex'];
                        if (v is int)
                          idx = v;
                        else if (v is num)
                          idx = v.toInt();
                      } catch (_) {
                        idx = null;
                      }
                    }

                    if (idx != null) {
                      counts[idx] = (counts[idx] ?? 0) + 1;
                    }
                  }
                  classCounts = counts;
                  // apply simple exponential smoothing so FPS display is stable
                  if (instantFps > 0) {
                    fps =
                        (fps * (1 - _fpsSmoothing)) +
                        (instantFps * _fpsSmoothing);
                  }
                });
              },
              onPerformanceMetrics: (metrics) {
                // store processing time and only accept plugin FPS when > 0
                if (!mounted) return;
                setState(() {
                  processingTimeMs = metrics.processingTimeMs;
                  if (metrics.fps > 0) {
                    fps = metrics.fps;
                  }
                });
                // keep console logs for debugging (use debugPrint to satisfy lints)
                if (kDebugMode) {
                  print('FPS: ${metrics.fps.toStringAsFixed(1)}');
                  print(
                    'Processing time: ${metrics.processingTimeMs.toStringAsFixed(1)}ms',
                  );
                }
              },
              onStreamingData: (stream) async {
                // stream contains detections, fps, processingTimeMs, originalImage etc.
                try {
                  final Map? map = stream as Map?;
                  if (map != null) {
                    if (map.containsKey('originalImage') &&
                        map['originalImage'] != null) {
                      final img = map['originalImage'];
                      if (img is Uint8List) {
                        _lastFrameBytes = img;
                      }
                    }

                    // Also handle detections to keep currentResults in sync
                    if (map.containsKey('detections') &&
                        map['detections'] is List) {
                      final detections = List<dynamic>.from(map['detections']);
                      if (!mounted) return;
                      setState(() {
                        currentResults = detections;
                        // compute classCounts
                        final Map<int, int> counts = {};
                        for (var d in detections) {
                          int? idx;
                          if (d is Map && d.containsKey('classIndex')) {
                            final v = d['classIndex'];
                            if (v is int)
                              idx = v;
                            else if (v is num)
                              idx = v.toInt();
                          }
                          if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
                        }
                        classCounts = counts;
                      });
                    }
                  }
                } catch (e) {
                  print('onStreamingData error: $e');
                }
              },
            ),
          ),

          // Overlay UI
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Objects: ${currentResults.length}',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'FPS: ${fps.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  // class counts
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(classLabels.length, (i) {
                      final count = classCounts[i] ?? 0;
                      return Text(
                        '$i: ${classLabels[i]} — $count',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          // Capture button bottom center
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () async {
                  // capture image bytes from last frame if available
                  if (_lastFrameBytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No frame available to capture')),
                    );
                    return;
                  }

                  // get location - try to obtain a fresh position, but
                  // fallback to last known position if unavailable.
                  Position? pos;
                  try {
                    bool serviceEnabled =
                        await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Location services disabled')),
                      );
                    } else {
                      LocationPermission permission =
                          await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }
                      if (permission == LocationPermission.deniedForever ||
                          permission == LocationPermission.denied) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Location permission denied')),
                        );
                      } else {
                        try {
                          // try to get current position with a short timeout
                          pos = await Geolocator.getCurrentPosition().timeout(
                            Duration(seconds: 5),
                            onTimeout: () {
                              // force timeout so we fall back below
                              throw Exception('timeout');
                            },
                          );
                        } catch (e) {
                          // try last known position explicitly as a fallback
                          try {
                            pos = await Geolocator.getLastKnownPosition();
                          } catch (_) {
                            pos = null;
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print('location error: $e');
                  }

                  // save image
                  try {
                    // Choose a writable directory depending on platform.
                    // Writing directly to /storage/emulated/0/... often fails on
                    // modern Android (scoped storage). Use the app-specific
                    // external directory returned by path_provider which does
                    // not require WRITE_EXTERNAL_STORAGE. Fallback to
                    // application documents directory when needed.
                    Directory? extDir;
                    if (Platform.isAndroid) {
                      try {
                        final sd = await getExternalStorageDirectory();
                        if (sd != null) {
                          // create a DeteksiSawit folder inside the app-specific
                          // external storage so the app can write without extra
                          // storage permissions.
                          extDir = Directory('${sd.path}/DeteksiSawit');
                        } else {
                          extDir = await getApplicationDocumentsDirectory();
                        }
                      } catch (e) {
                        // If anything goes wrong, fallback to app documents dir
                        extDir = await getApplicationDocumentsDirectory();
                      }
                    } else if (Platform.isIOS) {
                      extDir = await getApplicationDocumentsDirectory();
                    } else {
                      extDir = await getApplicationDocumentsDirectory();
                    }
                    if (!await extDir.exists()) {
                      await extDir.create(recursive: true);
                    }
                    final ts = DateTime.now().millisecondsSinceEpoch.toString();
                    // Save image to public Pictures/DeteksiSawit via platform
                    // channel (MediaStore). The native method returns a URI
                    // string on success.
                    String? imgPath;
                    if (Platform.isAndroid) {
                      try {
                        final channel = MethodChannel(
                          'com.agrinas.deteksi_sawit/media',
                        );
                        final filename = 'capture_$ts.png';
                        final base64 = base64Encode(_lastFrameBytes!);
                        final res = await channel
                            .invokeMethod('saveImageToGallery', {
                              'filename': filename,
                              'base64': base64,
                              'mimeType': 'image/png',
                            });
                        if (res is String) imgPath = res;
                      } catch (e) {
                        imgPath = null;
                      }
                    }

                    // prepare CSV content
                    final counts = classCounts;
                    final lines = <List<String>>[];
                    lines.add(['classLabel', 'count']);
                    for (var i = 0; i < classLabels.length; i++) {
                      lines.add([
                        i.toString(),
                        classLabels[i],
                        (counts[i] ?? 0).toString(),
                      ]);
                    }
                    final lat = pos != null ? pos.latitude.toString() : '';
                    final lon = pos != null ? pos.longitude.toString() : '';
                    lines.add(['latitude', 'longitude']);
                    lines.add([lat, lon]);
                    final csvContent = lines
                        .map(
                          (r) => r
                              .map((c) => '"${c.replaceAll('"', '""')}"')
                              .join(','),
                        )
                        .join('\n');

                    String? csvSavedPath;
                    // On Android, save CSV to Downloads via platform channel (MediaStore)
                    if (Platform.isAndroid) {
                      try {
                        final channel = MethodChannel(
                          'com.agrinas.deteksi_sawit/media',
                        );
                        final now = DateTime.now();
                        final formattedDate = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year.toString().substring(2)}_${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
                        final filename = 'Palm_$formattedDate.csv';
                        final base64 = base64Encode(csvContent.codeUnits);
                        final res = await channel.invokeMethod(
                          'saveCsvToDownloads',
                          {'filename': filename, 'base64': base64},
                        );
                        if (res == true) {
                          csvSavedPath = 'Download/$filename';
                        }
                      } catch (e) {
                        // fallback to app dir
                        final csvPath = '${extDir.path}/capture_$ts.csv';
                        final csvFile = File(csvPath);
                        await csvFile.writeAsString(csvContent);
                        csvSavedPath = csvPath;
                      }
                    } else {
                      final csvPath = '${extDir.path}/capture_$ts.csv';
                      final csvFile = File(csvPath);
                      await csvFile.writeAsString(csvContent);
                      csvSavedPath = csvPath;
                    }

                    // show preview from memory; if imgPath available include it
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('Capture saved'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.memory(_lastFrameBytes!, width: 250),
                              SizedBox(height: 8),
                              if (imgPath != null) Text('Image: $imgPath'),
                              if (csvSavedPath != null)
                                Text('CSV: $csvSavedPath'),
                              SizedBox(height: 6),
                              Text('Location:'),
                              Text(
                                pos != null
                                    ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
                                    : 'unknown',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    print('capture save error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save capture: $e')),
                    );
                  }
                },
                child: Icon(Icons.camera),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
