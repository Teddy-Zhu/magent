import 'package:flutter/material.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';

/// 兼容入口，保留旧的引用路径。新代码请直接使用 [AppLoading]。
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return AppLoading(message: message);
  }
}
