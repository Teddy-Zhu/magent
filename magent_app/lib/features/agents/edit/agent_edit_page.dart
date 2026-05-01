import 'package:flutter/material.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/storage/secure_storage.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Agent updated')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e, action: '连接失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Agent')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Agent URL',
                        hintText: 'http://192.168.1.100:9000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Token',
                        border: const OutlineInputBorder(),
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
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Save & Verify'),
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
