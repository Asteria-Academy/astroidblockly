// lib/screens/mission_control_screen.dart
import 'dart:convert';
import 'dart:typed_data';

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
  late final DateFormat _dateFormat;

  @override
  void initState() {
    super.initState();
    _currentProjects = widget.projects;
    _dateFormat = DateFormat.yMMMd().add_jm();
  }

  Future<void> _handleDelete(String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Project?"),
        content: Text("This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text("Delete"),
            onPressed: () => Navigator.pop(context, true),
          ),
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
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
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
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
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
          final previous = _currentProjects[index];
          _currentProjects[index] = Project(
            id: projectId,
            name: newName,
            lastModified: DateTime.now(),
            thumbnailData: previous.thumbnailData,
          );
          _currentProjects.sort(
            (a, b) => b.lastModified.compareTo(a.lastModified),
          );
        }
      });
    }
  }

  Uint8List? _decodeThumbnail(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) {
      return null;
    }
    final separatorIndex = dataUrl.indexOf(',');
    final payload =
        separatorIndex != -1 ? dataUrl.substring(separatorIndex + 1) : dataUrl;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _currentProjects.isEmpty
              ? Center(
                  child: Text(
                    "No adventures created yet.\nGo back and Create Adventure!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final extent = maxWidth < 520 ? maxWidth * 0.92 : 320.0;
                    final maxCrossAxisExtent =
                        extent.clamp(260.0, 420.0).toDouble();
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxCrossAxisExtent,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _currentProjects.length,
                      itemBuilder: (context, index) {
                        final project = _currentProjects[index];
                        return _ProjectCard(
                          project: project,
                          thumbnailBytes:
                              _decodeThumbnail(project.thumbnailData),
                          lastModifiedLabel:
                              _dateFormat.format(project.lastModified),
                          onOpen: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.webview,
                            arguments: {'action': 'open', 'id': project.id},
                          ),
                          onRename: () => _handleRename(project.id, project.name),
                          onDelete: () => _handleDelete(project.id),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.thumbnailBytes,
    required this.lastModifiedLabel,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Project project;
  final Uint8List? thumbnailBytes;
  final String lastModifiedLabel;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: const Color(0xFF121F45),
            border: Border.all(
              color: const Color(0xFF284072),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66172C5C),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: borderRadius.topLeft,
                    topRight: borderRadius.topRight,
                  ),
                  child: _ProjectPreview(bytes: thumbnailBytes),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.titanOne(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Color(0xFFA4F2FF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lastModifiedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onOpen,
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: Text(
                                'OPEN',
                                style: GoogleFonts.titanOne(
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: const Color(0xFF0B1433),
                                backgroundColor: const Color(0xFF6BF9FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Rename Adventure',
                            child: IconButton(
                              onPressed: onRename,
                              icon: const Icon(Icons.drive_file_rename_outline),
                              color: Colors.white70,
                            ),
                          ),
                          Tooltip(
                            message: 'Delete Adventure',
                            child: IconButton(
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline),
                              color: const Color(0xFFFF6B7A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPreview extends StatelessWidget {
  const _ProjectPreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D2A57),
            Color(0xFF18204A),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.auto_awesome,
            size: 44,
            color: Color(0x44FFFFFF),
          ),
          SizedBox(height: 8),
          Text(
            'Ready for launch',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
