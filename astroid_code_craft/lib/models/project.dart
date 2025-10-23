// lib/models/project.dart

class Project {
  final String id;
  final String name;
  final DateTime lastModified;
  final String? thumbnailData;

  Project({
    required this.id,
    required this.name,
    required this.lastModified,
    this.thumbnailData,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['last_modified'] as int),
      thumbnailData: json['thumbnail_data'] as String?,
    );
  }
}
