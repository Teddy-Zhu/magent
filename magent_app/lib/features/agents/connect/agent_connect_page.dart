import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class AgentConnectPage extends StatefulWidget {
  const AgentConnectPage({super.key});

  @override
  State<AgentConnectPage> createState() => _AgentConnectPageState();
}

class _AgentConnectPageState extends State<AgentConnectPage> {
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
      setState(() => _connecting = false);
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
                decoration: InputDecoration(
                  labelText: l10n.agentsName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.agentsUrl,
                  hintText: 'http://192.168.1.100:9000',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: l10n.agentsToken,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    v?.isEmpty ?? true ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const CircularProgressIndicator()
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
