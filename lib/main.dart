import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MaterialApp(home: const ConverterScreen(), theme: ThemeData.dark()));

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});
  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  // Новые абсолютные пути для Android 16
  final String _inputDir = '/storage/emulated/0/DCIM/Insta360';
  final String _outputDir = '/storage/emulated/0/Download';

  double _yaw = -0.56;
  double _pitch = 0.6;
  double _roll = -90.0;
  String _status = 'Настройте углы и скопируйте команду';

  Widget _buildSlider(String label, double val, double min, double max, ValueChanged<double> cb) {
    return Column(children: [
      Text('$label: ${val.toStringAsFixed(2)}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      Slider(value: val, min: min, max: max, onChanged: cb),
    ]);
  }

  void _generateAndCopy() {
    // Формируем полноценный bash-скрипт для Termux
    String bashScript = '''
#!/bin/bash
cd "$_inputDir" || { echo "Папка Insta360 не найдена"; exit 1; }
for file in *.insp; do
  [ -e "\$file" ] || continue
  base="\${file%.*}"
  echo "Обработка: \$file"
  ffmpeg -i "\$file" -filter_complex "[v:0]crop=iw/2:ih:0:0,v360=input=fisheye:output=hequirect:h_fov=200:v_fov=200:yaw=0:pitch=0:roll=0[left_eye]; [v:0]crop=iw/2:ih:iw/2:0,v360=input=fisheye:output=hequirect:h_fov=200:v_fov=200:yaw=$_yaw:pitch=$_pitch:roll=$_roll[right_eye]; [left_eye][right_eye]hstack=inputs=2[sbs]" -map "[sbs]" -y "$_outputDir/\${base}_sbs_180.png"
done
echo "=== Все файлы успешно обработаны! ==="
''';

    // Формируем плоскую команду для вставки в Termux
    String termuxCommand = "cat << 'EOF' > ~/run.sh\n$bashScript\nEOF\nchmod +x ~/run.sh && ~/run.sh";

    Clipboard.setData(ClipboardData(text: termuxCommand));
    setState(() {
      _status = 'Команда скопирована!\n\nОткройте Termux, вставьте её и нажмите Enter.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INSP to SBS Termux Helper')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text('Вход: $_inputDir', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('Выход: $_outputDir', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const Divider(height: 30),
            _buildSlider('Yaw (Рыскание)', _yaw, -180, 180, (v) => setState(() => _yaw = v)),
            _buildSlider('Pitch (Тангаж)', _pitch, -90, 90, (v) => setState(() => _pitch = v)),
            _buildSlider('Roll (Крен)', _roll, -180, 180, (v) => setState(() => _roll = v)),
            const Divider(height: 30),
            Expanded(child: Center(child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.green)))),
            ElevatedButton.icon(
              onPressed: _generateAndCopy,
              icon: const Icon(Icons.copy),
              label: const Text('СКОПИРОВАТЬ КОМАНДУ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size.fromHeight(55)),
            )
          ],
        ),
      ),
    );
  }
}
