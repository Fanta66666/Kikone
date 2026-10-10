import 'package:flutter/material.dart';

/// 为原本作为 Tab 内容、自身没有导航栏的页面提供统一的外层导航壳。
///
/// iOS 三入口结构下，历史 / 字幕库等页面需要以独立路由打开，
/// 该包装保证顶部标题与返回按钮存在。
class PushedPageScaffold extends StatelessWidget {
  const PushedPageScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
