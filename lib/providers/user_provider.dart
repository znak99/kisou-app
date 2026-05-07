import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import 'api_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(apiClientProvider));
});

final userProvider = AsyncNotifierProvider<UserController, User?>(
  UserController.new,
);

class UserController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return null;
  }

  Future<User> getMe() async {
    state = const AsyncLoading<User?>();
    final user = await ref.read(userServiceProvider).getMe();
    state = AsyncData(user);
    return user;
  }

  Future<User> updateMe(UserUpdate update) async {
    state = const AsyncLoading<User?>();
    final user = await ref.read(userServiceProvider).updateMe(update);
    state = AsyncData(user);
    return user;
  }

  Future<void> deleteMe() async {
    state = const AsyncLoading<User?>();
    await ref.read(userServiceProvider).deleteMe();
    state = const AsyncData(null);
  }
}
