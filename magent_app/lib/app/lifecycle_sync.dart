import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';

class LifecycleSync extends ConsumerStatefulWidget {
  final Widget child;

  const LifecycleSync({super.key, required this.child});

  @override
  ConsumerState<LifecycleSync> createState() => _LifecycleSyncState();
}

class _LifecycleSyncState extends ConsumerState<LifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider)?.handleForeground();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        engine?.handleForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        engine?.handleBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
