import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;

void main() => runApp(MaterialApp(home: const ConverterScreen(), theme: ThemeData.dark()));

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});
  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  // Обновленный абсолютный путь по умолчанию к папке Insta360
  String _dirPath = '/storage/emulated/0/DCIM/Insta360'; 
  List<File> _files = [];
  bool _loading = false;
  double _progress = 0.0;
  String _log = 'Нажмите "Сканировать", чтобы найти файлы .insp';

  double _yaw = -0.56;
  double _pitch = 0.6;
  double _roll = -90.0;

  @override
  void initState() {
    super.initState();
    _autoScan();
  }

  // Автоматический поиск папки при старте приложения
  Future<void> _autoScan() async {
    try {
      final List<String> possiblePaths = [
        '/storage/emulated/0/DCIM/Insta360',
        '/storage/emulated/0/Download',
      ];

      String targetPath = '';
      for (var path in possiblePaths) {
        if (Directory(path).existsSync()) {
          targetPath = path;
          break;
        }
      }

      if (targetPath.isEmpty) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) targetPath = dir.path;
      }

      if (targetPath.isNotEmpty) {
        _scanFolder(targetPath);
      }
    } catch (e) {
      setState(() => _log = 'Ошибка сканирования: $e');
    }
  }

  void _scanFolder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      setState(() { _dirPath = path; _log = 'Папка пуста или не найдена'; _files = []; });
      return;
    }
    final inspFiles = dir.listSync().whereType<File>().where((f) => p.extension(f.path).toLowerCase() == '.insp').toList();
    setState(() { _dirPath = path; _files = inspFiles; _log = 'Найдено файлов: ${inspFiles.length}'; });
  }

  Future<void> _convert() async {
    if (_files.isEmpty) return;
    setState(() { _loading = true; _progress = 0.0; });

    for (int i = 0; i < _files.length; i++) {
      String inP = _files[i].path;
      String outP = p.join(p.dirname(inP), '${p.basenameWithoutExtension(inP)}_sbs_180.png');
      
      setState(() => _log = 'Обработка (${i+1}/${_files.length}): ${p.basename(inP)}');

      String cmd = '-i "$inP" -filter_complex "[v:0]crop=iw/2:ih:0:0,v360=input=fisheye:output=hequirect:h_fov=200:v_fov=200:yaw=0:pitch=0:roll=0[left_eye]; [v:0]crop=iw/2:ih:iw/2:0,v360=input=fisheye:output=hequirect:h_fov=200:v_fov=200:yaw=$_yaw:pitch=$_pitch:roll=$_roll[right_eye]; [left_eye][right_eye]hstack=inputs=2[sbs]" -map "[sbs]" -y "$outP"';

      await FFmpegKit.execute(cmd);
      setState(() => _progress = (i + 1) / _files.length);
    }
    setState(() { _loading = false; _log = 'Готово! Все файлы обработаны.'; });
  }

  Widget _buildSlider(String label, double val, double min, double max, ValueChanged<double> cb) {
    return Column(children: [
      Text('$label: ${val.toStringAsFixed(2)}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      Slider(value: val, min: min, max: max, onChanged: _loading ? null : cb),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INSP 180 SBS Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text('Текущий путь: $_dirPath', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, textAlign: TextAlign.center),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Обновленные кнопки с точными новыми путями
                        ElevatedButton(onPressed: () => _scanFolder('/storage/emulated/0/DCIM/Insta360'), child: const Text('Папка Insta360')),
                        ElevatedButton(onPressed: () => _scanFolder('/storage/emulated/0/Download'), child: const Text('Загрузки')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            _buildSlider('Yaw (Рыскание)', _yaw, -180, 180, (v) => setState(() => _yaw = v)),
            _buildSlider('Pitch (Тангаж)', _pitch, -90, 90, (v) => setState(() => _pitch = v)),
            _buildSlider('Roll (Крен)', _roll, -180, 180, (v) => setState(() => _roll = v)),
            const Divider(height: 20),
            if (_loading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 10),
            ],
            Expanded(child: Center(child: Text(_log, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)))),
            ElevatedButton(
              onPressed: (_loading || _files.isEmpty) ? null : _convert,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              child: const Text('СТАРТ', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
