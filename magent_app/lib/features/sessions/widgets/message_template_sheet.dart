import 'package:flutter/material.dart';
import 'package:magent_app/core/services/message_template_service.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class MessageTemplateSheet extends StatefulWidget {
  final ValueChanged<String> onSelect;

  const MessageTemplateSheet({super.key, required this.onSelect});

  static void show(
    BuildContext context, {
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MessageTemplateSheet(onSelect: onSelect),
    );
  }

  @override
  State<MessageTemplateSheet> createState() => _MessageTemplateSheetState();
}

class _MessageTemplateSheetState extends State<MessageTemplateSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = MessageTemplateService();
  List<String> _recent = [];
  List<MessageTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.getRecent(),
      _service.getTemplates(),
    ]);
    if (mounted) {
      setState(() {
        _recent = results[0] as List<String>;
        _templates = results[1] as List<MessageTemplate>;
        _loading = false;
      });
    }
  }

  void _select(String text) {
    Navigator.pop(context);
    widget.onSelect(text);
  }

  void _saveAsTemplate(String content) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.templatesSaveAs),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.templatesNameHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await _service.saveTemplate(name, content);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(int index) async {
    await _service.deleteTemplate(index);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.templatesRecent),
                Tab(text: l10n.templatesSaved),
              ],
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRecentList(scrollController),
                        _buildTemplateList(scrollController),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentList(ScrollController scrollController) {
    if (_recent.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.templatesNoRecent,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _recent.length,
      itemBuilder: (context, index) {
        final msg = _recent[index];
        return ListTile(
          dense: true,
          title: Text(
            msg,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.bookmark_border, size: 18),
            onPressed: () => _saveAsTemplate(msg),
            tooltip: AppLocalizations.of(context)!.templatesSaveAs,
          ),
          onTap: () => _select(msg),
        );
      },
    );
  }

  Widget _buildTemplateList(ScrollController scrollController) {
    if (_templates.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.templatesNoSaved,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final t = _templates[index];
        return ListTile(
          dense: true,
          title: Text(
            t.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            t.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteTemplate(index),
            tooltip: AppLocalizations.of(context)!.templatesDelete,
          ),
          onTap: () => _select(t.content),
        );
      },
    );
  }
}
