import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;

void main() => runApp(MaterialApp(home: const ConverterScreen(), theme: ThemeData.dark()));

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});
  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  String? _dirPath;
  List<File> _files = [];
  bool _loading = false;
  double _progress = 0.0;
  String _log = 'Выберите папку с файлами .insp';

  double _yaw = -0.56;
  double _pitch = 0.6;
  double _roll = -90.0;

  Future<void> _pickFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    final dir = Directory(path);
    if (!dir.existsSync()) return;
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
            ElevatedButton(onPressed: _loading ? null : _pickFolder, child: const Text('Выбрать папку')),
            const SizedBox(height: 5),
            Text(_dirPath ?? 'Папка не выбрана', style: const TextStyle(color: Colors.grey), maxLines: 1),
            const Divider(height: 30),
            _buildSlider('Yaw (Рыскание)', _yaw, -180, 180, (v) => setState(() => _yaw = v)),
            _buildSlider('Pitch (Тангаж)', _pitch, -90, 90, (v) => setState(() => _pitch = v)),
            _buildSlider('Roll (Крен)', _roll, -180, 180, (v) => setState(() => _roll = v)),
            const Divider(height: 30),
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
