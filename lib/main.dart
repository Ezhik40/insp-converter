import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; // Импортируем плагин запуска

void main() => runApp(MaterialApp(home: const ConverterScreen(), theme: ThemeData.dark()));

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});
  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final String _inputDir = '/storage/emulated/0/DCIM/Insta360';
  final String _outputDir = '/storage/emulated/0/DCIM/Insta360';

  double _yaw = 0.0;     
  double _pitch = 0.0;   
  double _roll = -90.0;  
  String _status = 'Настройте точные углы, FOV и скопируйте команду';

  final TextEditingController _fovController = TextEditingController(text: '200');

  @override
  void dispose() {
    _fovController.dispose();
    super.dispose();
  }

  // Функция для открытия Termux на Android
  Future<void> _openTermux() async {
    // Используем нативную схему Android для открытия приложения по его ID пакета
    final Uri termuxUri = Uri.parse('android-app://com.termux');
    try {
      if (await canLaunchUrl(termuxUri)) {
        await launchUrl(termuxUri, mode: LaunchMode.externalApplication);
      } else {
        // Альтернативный вариант запуска через кастомную схему
        final Uri altUri = Uri.parse('intent:#Intent;component=com.termux/.MainActivity;end');
        await launchUrl(altUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() {
        _status = 'Не удалось запустить Termux автоматически.\nПожалуйста, откройте его вручную с рабочего стола.';
      });
    }
  }

  Widget _buildSlider({
    required String label,
    required double val,
    required double min,
    required double max,
    required int divisions,
    required int fractionDigits,
    required ValueChanged<double> cb,
  }) {
    return Column(children: [
      Text('$label: ${val.toStringAsFixed(fractionDigits)}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      Slider(
        value: val, 
        min: min, 
        max: max, 
        divisions: divisions, 
        onChanged: cb,
      ),
    ]);
  }

  void _generateAndCopy() {
    String fov = _fovController.text.trim();
    if (fov.isEmpty || double.tryParse(fov) == null) {
      fov = '200';
    }

    String bashScript = '''
#!/bin/bash
cd "$_inputDir" || { echo "Папка Insta360 не найдена"; exit 1; }
for file in *.insp; do
  [ -e "\$file" ] || continue
  base="\${file%.*}"
  echo "Обработка: \$file"
  ffmpeg -i "\$file" -filter_complex "[v:0]crop=iw/2:ih:0:0,v360=input=fisheye:output=hequirect:h_fov=$fov:v_fov=$fov:yaw=0:pitch=0:roll=0[left_eye]; [v:0]crop=iw/2:ih:iw/2:0,v360=input=fisheye:output=hequirect:h_fov=$fov:v_fov=$fov:yaw=${_yaw.toStringAsFixed(1)}:pitch=${_pitch.toStringAsFixed(1)}:roll=${_roll.round()}[right_eye]; [left_eye][right_eye]hstack=inputs=2[sbs]" -map "[sbs]" -y "$_outputDir/\${base}_sbs_180.png"
done
echo "=== Все файлы успешно обработаны! ==="
''';

    String termuxCommand = "cat << 'EOF' > ~/run.sh\n$bashScript\nEOF\nchmod +x ~/run.sh && ~/run.sh";

    Clipboard.setData(ClipboardData(text: termuxCommand));
    setState(() {
      _status = 'Команда скопирована!\n\nНажмите кнопку «ОТКРЫТЬ TERMUX», вставьте её и запустите.';
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
                child: Text('Рабочая папка: $_inputDir', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Угол обзора (FOV): ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: TextField(
                    controller: _fovController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 5),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                ),
                const Text(' °', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            
            _buildSlider(
              label: 'Yaw (Рыскание)', 
              val: _yaw, min: -2.0, max: 2.0, divisions: 40, fractionDigits: 1,
              cb: (v) => setState(() => _yaw = v),
            ),
            
            _buildSlider(
              label: 'Pitch (Тангаж)', 
              val: _pitch, min: -2.0, max: 2.0, divisions: 40, fractionDigits: 1,
              cb: (v) => setState(() => _pitch = v),
            ),
            
            _buildSlider(
              label: 'Roll (Крен)', 
              val: _roll, min: -90.0, max: 90.0, divisions: 180, fractionDigits: 0,
              cb: (v) => setState(() => _roll = v),
            ),
            
            const Divider(height: 20),
            Expanded(child: Center(child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.green)))),
            
            // Блок кнопок управления внизу экрана
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _generateAndCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('СКОПИРОВАТЬ КОМАНДУ'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _openTermux,
                  icon: const Icon(Icons.terminal),
                  label: const Text('ОТКРЫТЬ TERMUX', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, minimumSize: const Size.fromHeight(50)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
