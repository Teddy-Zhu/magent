import 'package:flutter/material.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';

class AgentEditPage extends StatefulWidget {
  final String agentId;

  const AgentEditPage({super.key, required this.agentId});

  @override
  State<AgentEditPage> createState() => _AgentEditPageState();
}

class _AgentEditPageState extends State<AgentEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _storage = AgentStorage();
  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadAgent();
  }

  Future<void> _loadAgent() async {
    final agents = await _storage.loadAgents();
    for (final agent in agents) {
      if (agent['id'] == widget.agentId) {
        _nameController.text = agent['name'] ?? '';
        _urlController.text = agent['url'] ?? '';
        _tokenController.text = agent['token'] ?? '';
        break;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Verify connection with new settings
      final client = ApiClient(
        baseUrl: _urlController.text,
        token: _tokenController.text,
      );
      await client.getAgentInfo();

      await _storage.saveAgent(
        widget.agentId,
        _urlController.text,
        _tokenController.text,
        _nameController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.agentUpdated)),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.agentsEdit)),
      body: _loading
          ? const AppLoading()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.agentsName,
                        prefixIcon: const Icon(Icons.label),
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
                        prefixIcon: const Icon(Icons.link),
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.fieldRequired : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: l10n.agentsToken,
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscureToken = !_obscureToken),
                        ),
                      ),
                      obscureText: _obscureToken,
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.fieldRequired : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(l10n.agentsSaveVerify),
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
