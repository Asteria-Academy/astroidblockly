// lib/screens/mission_control_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../router/app_router.dart';

class MissionControlScreen extends StatefulWidget {
  const MissionControlScreen({
    super.key,
    required this.projects,
    required this.controller,
  });

  final List<Project> projects;
  final InAppWebViewController? controller;

  @override
  State<MissionControlScreen> createState() => _MissionControlScreenState();
}

class _MissionControlScreenState extends State<MissionControlScreen> {
  late List<Project> _currentProjects;

  @override
  void initState() {
    super.initState();
    _currentProjects = widget.projects;
  }

  Future<void> _handleDelete(String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Project?"),
        content: Text("This action cannot be undone."),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text("Delete"), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirmed == true && widget.controller != null) {
      await widget.controller!.callAsyncJavaScript(
        functionBody: "window.deleteProject(arguments[0]);",
        arguments: {'id': projectId},
      );
      setState(() {
        _currentProjects.removeWhere((p) => p.id == projectId);
      });
    }
  }

  Future<void> _handleRename(String projectId, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Rename Project"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Save"),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, nameController.text);
              }
            },
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && widget.controller != null) {
      await widget.controller!.callAsyncJavaScript(
        functionBody: "window.renameProject(arguments[0], arguments[1]);",
        arguments: {'id': projectId, 'name': newName},
      );
      setState(() {
        final index = _currentProjects.indexWhere((p) => p.id == projectId);
        if (index != -1) {
          _currentProjects[index] = Project(
              id: projectId,
              name: newName,
              lastModified: DateTime.now());
          _currentProjects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      appBar: AppBar(
        title: Text('Mission Control', style: GoogleFonts.titanOne()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _currentProjects.isEmpty
          ? Center(
              child: Text(
                "No adventures created yet.\nGo back and Create Adventure!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _currentProjects.length,
              itemBuilder: (context, index) {
                final project = _currentProjects[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  color: const Color(0xFF1A244A),
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_outlined, color: const Color(0xFFA4F2FF)),
                    title: Text(project.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "Last modified: ${DateFormat.yMMMd().add_jm().format(project.lastModified)}",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onTap: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.webview,
                      arguments: {'action': 'load_project', 'id': project.id},
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.drive_file_rename_outline, color: Colors.white70),
                          tooltip: "Rename",
                          onPressed: () => _handleRename(project.id, project.name),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: "Delete",
                          onPressed: () => _handleDelete(project.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}