import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:xml/xml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ProjectSelectionScreen(),
    );
  }
}

class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  String? selectedProjectPath;
  String? apiKey;
  bool isProcessing = false;
  String statusMessage = '';

  void _selectProject() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        selectedProjectPath = result;
        statusMessage = 'Selected project: $selectedProjectPath';
      });
      _promptForApiKey();
    } else {
      _showErrorMessage('No project folder selected.');
    }
  }

  void _promptForApiKey() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Google Maps API Key'),
        content: TextField(
          onChanged: (value) => apiKey = value,
          decoration: const InputDecoration(hintText: 'API Key'),
          keyboardType: TextInputType.visiblePassword,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (apiKey?.isEmpty ?? true) {
                _showErrorMessage('Please enter a valid API key.');
              } else {
                _configureProject();
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _configureProject() async {
    if (selectedProjectPath == null) return;
    setState(() {
      isProcessing = true;
      statusMessage = 'Configuring project...';
    });

    try {
      final pubspecFile = File('$selectedProjectPath/pubspec.yaml');
      if (await pubspecFile.exists()) {
        final pubspecContent = await pubspecFile.readAsString();
        if (!pubspecContent.contains('google_maps_flutter:')) {
          final updatedContent = pubspecContent.replaceFirst(
            'dependencies:',
            'dependencies:\n  google_maps_flutter: ^2.2.0\n',
          );
          await pubspecFile.writeAsString(updatedContent);
        }
      }

      final shell = Shell(workingDirectory: selectedProjectPath);
      await shell.run('flutter pub get');

      await _configureAndroid();
      await _configureIOS();

      setState(() {
        isProcessing = false;
        statusMessage = 'Google Maps integrated successfully!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps integrated successfully!')),
      );
    } catch (e) {
      setState(() {
        isProcessing = false;
        statusMessage = 'Error: $e';
      });
      _showErrorMessage('Error: $e');
    }
  }

  Future<void> _configureAndroid() async {
    final androidManifest =
        File('$selectedProjectPath/android/app/src/main/AndroidManifest.xml');
    if (await androidManifest.exists()) {
      final document = XmlDocument.parse(await androidManifest.readAsString());
      final applicationElement = document.findAllElements('application').first;
      applicationElement.children.add(XmlElement(
        XmlName('meta-data'),
        [
          XmlAttribute(
              XmlName('android:name'), 'com.google.android.geo.API_KEY'),
          XmlAttribute(XmlName('android:value'), apiKey!),
        ],
      ));
      await androidManifest.writeAsString(document.toXmlString(pretty: true));
    }
  }

  Future<void> _configureIOS() async {
    final infoPlist = File('$selectedProjectPath/ios/Runner/Info.plist');
    if (await infoPlist.exists()) {
      var content = await infoPlist.readAsString();
      if (!content.contains('<key>GMSApiKey</key>')) {
        final insertionIndex = content.lastIndexOf('</dict>');
        content = content.substring(0, insertionIndex) +
            '\n    <key>GMSApiKey</key>\n    <string>$apiKey</string>\n' +
            content.substring(insertionIndex);
        await infoPlist.writeAsString(content);
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Flutter Project')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Set up Google Maps for your Flutter project',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (selectedProjectPath != null)
                Text(
                  'Selected Project: $selectedProjectPath',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _selectProject,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Flutter Project'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              if (isProcessing) const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text(
                statusMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
