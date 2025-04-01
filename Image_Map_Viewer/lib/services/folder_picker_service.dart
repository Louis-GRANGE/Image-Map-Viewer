
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FolderPicker extends StatelessWidget {
  final Function(String) onFolderSelect;

  const FolderPicker({super.key, required this.onFolderSelect});

  Future<void> _pickFolder(BuildContext context) async {
    String? selectedFolder = await FilePicker.platform.getDirectoryPath();
    if (selectedFolder != null) {
      onFolderSelect(selectedFolder); // Trigger callback when a folder is selected
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () => _pickFolder(context),
          child: const Text("Select Folder"),
        ),
        const SizedBox(height: 10),
        Text(
          'Select a folder to load images and place them on the map.',
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }
}
