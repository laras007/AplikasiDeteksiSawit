import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
    List<FileSystemEntity> foundFiles = [];
    if (Platform.isAndroid) {
      // Cari di folder Download untuk file Palm_*.csv
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final allFiles = downloadsDir.listSync();
        final palmFiles = allFiles.where((f) {
          final name = p.basename(f.path);
          return name.startsWith('Palm_') && name.endsWith('.csv');
        }).toList();
        foundFiles.addAll(palmFiles);
      }
      // Tambahkan juga dari folder app jika ada (DeteksiSawit)
      Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final appDir = Directory('${extDir.path}/DeteksiSawit');
        if (await appDir.exists()) {
          final appFiles = appDir.listSync().where((f) => f.path.endsWith('.csv')).toList();
          foundFiles.addAll(appFiles);
        }
      }
    } else {
      // iOS atau lain, cari di documents
      final docDir = await getApplicationDocumentsDirectory();
      if (await docDir.exists()) {
        final docFiles = docDir.listSync().where((f) => f.path.endsWith('.csv')).toList();
        foundFiles.addAll(docFiles);
      }
    }
    // Urutkan file terbaru di atas
    foundFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() {
      files = foundFiles;
    });
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
