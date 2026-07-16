import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected bottom-navigation tab index for [RootShell]. Exposed as a provider
/// so any screen can request a tab switch (e.g. home → profile for location).
final shellTabProvider = NotifierProvider<ShellTabController, int>(
  ShellTabController.new,
);

class ShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

class ShellTab {
  const ShellTab._();

  static const home = 0;
  static const forecast = 1;
  static const profile = 2;
}
