import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';

/// Service to handle saving, loading, listing, and deleting projects locally.
class ProjectService {
  Future<Directory> _getProjectsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory(p.join(appDir.path, 'caption_trans_projects'));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  /// Lists all saved projects, sorted by [updatedAt] descending.
  Future<List<Project>> listProjects() async {
    final dir = await _getProjectsDirectory();
    final List<Project> projects = [];

    final files = dir.listSync();
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          projects.add(Project.fromJson(jsonMap));
        } catch (e) {
          debugPrint(
            'Warning: Failed to load project file ${file.path}: $e',
          );
          continue;
        }
      }
    }

    // Sort by latest updated first
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  /// Saves a project to local storage using atomic write (temp + rename).
  Future<void> saveProject(Project project) async {
    final dir = await _getProjectsDirectory();
    final file = File(p.join(dir.path, '${project.id}.json'));
    final tmpFile = File(p.join(dir.path, '${project.id}.json.tmp'));

    final jsonString = jsonEncode(project.toJson());
    await tmpFile.writeAsString(jsonString, flush: true);
    await tmpFile.rename(file.path);
  }

  /// Deletes a project by ID.
  Future<void> deleteProject(String projectId) async {
    final dir = await _getProjectsDirectory();
    final file = File(p.join(dir.path, '$projectId.json'));

    if (await file.exists()) {
      await file.delete();
    }
  }
}
