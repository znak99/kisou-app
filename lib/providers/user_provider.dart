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
    try {
      final user = await ref.read(userServiceProvider).getMe();
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      // Surface an error state (with retry) instead of staying stuck on the
      // loading spinner forever — audit B5.
      state = AsyncError<User?>(error, stackTrace);
      rethrow;
    }
  }

  Future<User> updateMe(UserUpdate update) async {
    final previous = state;
    state = const AsyncLoading<User?>();
    try {
      final user = await ref.read(userServiceProvider).updateMe(update);
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      // Keep the profile usable by restoring the prior data; the caller
      // surfaces the failure (e.g. a snackbar).
      state = previous.hasValue ? previous : AsyncError<User?>(error, stackTrace);
      rethrow;
    }
  }

  Future<User> resetData() async {
    final previous = state;
    state = const AsyncLoading<User?>();
    try {
      final user = await ref.read(userServiceProvider).resetData();
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      state = previous.hasValue ? previous : AsyncError<User?>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteMe() async {
    final previous = state;
    state = const AsyncLoading<User?>();
    try {
      await ref.read(userServiceProvider).deleteMe();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = previous.hasValue ? previous : AsyncError<User?>(error, stackTrace);
      rethrow;
    }
  }
}
