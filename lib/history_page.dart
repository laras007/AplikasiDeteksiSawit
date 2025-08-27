import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity> files = [];

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  Future<void> loadFiles() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
      if (dir != null) {
        dir = Directory('${dir.path}/DeteksiSawit');
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    if (dir != null && await dir.exists()) {
      final allFiles = dir.listSync();
      final csvFiles = allFiles.where((f) => f.path.endsWith('.csv')).toList();
      setState(() {
        files = csvFiles;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Capture')),
      body: files.isEmpty
          ? const Center(child: Text('Belum ada file hasil capture.'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final filename = file.path.split(Platform.pathSeparator).last;
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(filename),
                  onTap: () {
                    OpenFile.open(file.path);
                  },
                );
              },
            ),
    );
  }
}
