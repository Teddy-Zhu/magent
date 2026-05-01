import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MessageTemplateService {
  static const _recentKey = 'msg_recent_messages';
  static const _templatesKey = 'msg_saved_templates';
  static const _maxRecent = 20;

  /// Add a message to recent history (called when user sends a message)
  Future<void> addRecent(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString(_recentKey));
    // Remove duplicate if exists
    list.remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > _maxRecent) list.removeRange(_maxRecent, list.length);
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  /// Get recent messages
  Future<List<String>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(_recentKey));
  }

  /// Clear recent messages
  Future<void> clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  /// Get saved templates
  Future<List<MessageTemplate>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templatesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => MessageTemplate.fromJson(e)).toList();
  }

  /// Save a new template
  Future<void> saveTemplate(String name, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getTemplates();
    templates.insert(0, MessageTemplate(name: name, content: content, createdAt: DateTime.now()));
    await prefs.setString(_templatesKey, jsonEncode(templates.map((e) => e.toJson()).toList()));
  }

  /// Delete a template by index
  Future<void> deleteTemplate(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getTemplates();
    if (index < 0 || index >= templates.length) return;
    templates.removeAt(index);
    await prefs.setString(_templatesKey, jsonEncode(templates.map((e) => e.toJson()).toList()));
  }

  List<String> _decodeList(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<String>().toList();
    } catch (_) {
      return [];
    }
  }
}

class MessageTemplate {
  final String name;
  final String content;
  final DateTime createdAt;

  MessageTemplate({required this.name, required this.content, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MessageTemplate.fromJson(Map<String, dynamic> json) => MessageTemplate(
        name: json['name'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
