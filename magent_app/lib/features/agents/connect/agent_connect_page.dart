import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class AgentConnectPage extends ConsumerStatefulWidget {
  const AgentConnectPage({super.key});

  @override
  ConsumerState<AgentConnectPage> createState() => _AgentConnectPageState();
}

class _AgentConnectPageState extends ConsumerState<AgentConnectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController(text: 'http://');
  final _tokenController = TextEditingController();
  final _storage = AgentStorage();
  bool _connecting = false;

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _connecting = true);

    try {
      final client = ApiClient(
        baseUrl: _urlController.text,
        token: _tokenController.text,
      );

      // 验证连接
      await client.getAgentInfo();

      // 保存
      final id = const Uuid().v4();
      await _storage.saveAgent(
        id,
        _urlController.text,
        _tokenController.text,
        _nameController.text,
      );
      // 新加入的 agent 自动设为激活，避免 activeApiProvider 仍指向 null。
      await _storage.setActiveAgent(id);
      // 让所有依赖 activeApiProvider 的页面（项目列表等）刷新。
      ref.invalidate(activeApiProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.agentConnected)),
        );
        context.go('/projects');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(l10n, e, action: l10n.agentsConnectFailed),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.isEmpty) {
      _nameController.text = l10n.agentsDefaultName;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.agentsConnect)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.agentsName),
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.agentsUrl,
                  hintText: 'http://192.168.1.100:9000',
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(labelText: l10n.agentsToken),
                obscureText: true,
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _connecting ? null : _connect,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(l10n.agentsConnect),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
