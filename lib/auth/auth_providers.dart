import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/providers.dart';
import '../data/db/database.dart';
import '../sync/sync_engine.dart';
import 'auth_repository.dart';

const _accountChoiceKey = 'onboarding.accountChoiceComplete';
const _activeProfileKey = 'account.activeProfileId';

enum AccountMode { local, signedIn, reconnectRequired }

class AccountState {
  const AccountState({
    required this.mode,
    required this.accountChoiceComplete,
    this.user,
    this.profileUserId,
    this.busy = false,
    this.mergeRequired = false,
    this.passwordRecovery = false,
    this.error,
  });

  final AccountMode mode;
  final bool accountChoiceComplete;
  final User? user;
  final String? profileUserId;
  final bool busy;
  final bool mergeRequired;
  final bool passwordRecovery;
  final Object? error;

  bool get isSignedIn => mode == AccountMode.signedIn && user != null;

  AccountState copyWith({
    AccountMode? mode,
    bool? accountChoiceComplete,
    User? user,
    bool clearUser = false,
    String? profileUserId,
    bool clearProfile = false,
    bool? busy,
    bool? mergeRequired,
    bool? passwordRecovery,
    Object? error,
    bool clearError = false,
  }) => AccountState(
    mode: mode ?? this.mode,
    accountChoiceComplete: accountChoiceComplete ?? this.accountChoiceComplete,
    user: clearUser ? null : (user ?? this.user),
    profileUserId: clearProfile ? null : (profileUserId ?? this.profileUserId),
    busy: busy ?? this.busy,
    mergeRequired: mergeRequired ?? this.mergeRequired,
    passwordRecovery: passwordRecovery ?? this.passwordRecovery,
    error: clearError ? null : (error ?? this.error),
  );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppConfig.hasSupabase) return AuthRepository();
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } on AssertionError {
    client = null;
  }
  return AuthRepository(client: client);
});

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, AccountState>(
      AccountController.new,
    );

class AccountController extends AsyncNotifier<AccountState> {
  StreamSubscription<AuthState>? _subscription;
  Future<void>? _activation;
  String? _activationUserId;

  @override
  Future<AccountState> build() async {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    final prefs = await SharedPreferences.getInstance();
    final repository = ref.read(authRepositoryProvider);
    final storedProfile = prefs.getString(_activeProfileKey);
    final user = repository.currentUser;
    final choice = prefs.getBool(_accountChoiceKey) ?? false;
    _subscription = repository.authChanges.listen(_onAuthChange);
    if (user != null) {
      await prefs.setBool(_accountChoiceKey, true);
      final profile = ref.read(dataProfileControllerProvider);
      final client = repository.client;
      if (profile.isGuest && client != null) {
        final engine = SyncEngine(
          database: ref.read(appDatabaseProvider),
          client: client,
          userId: user.id,
        );
        if (await engine.hasLocalData()) {
          if (await engine.hasCloudData()) {
            return AccountState(
              mode: AccountMode.signedIn,
              accountChoiceComplete: true,
              user: user,
              profileUserId: user.id,
              mergeRequired: true,
            );
          }
          await engine.importAll();
        }
      }
      await prefs.setString(_activeProfileKey, user.id);
      await ref
          .read(dataProfileControllerProvider.notifier)
          .switchToUser(user.id);
      return AccountState(
        mode: AccountMode.signedIn,
        accountChoiceComplete: true,
        user: user,
        profileUserId: user.id,
      );
    }
    if (storedProfile != null) {
      return AccountState(
        mode: AccountMode.reconnectRequired,
        accountChoiceComplete: true,
        profileUserId: storedProfile,
      );
    }
    return AccountState(mode: AccountMode.local, accountChoiceComplete: choice);
  }

  Future<void> chooseLocal() async {
    final current = state.value ?? await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_accountChoiceKey, true);
    await prefs.remove(_activeProfileKey);
    state = AsyncData(
      current.copyWith(
        mode: AccountMode.local,
        accountChoiceComplete: true,
        clearUser: true,
        clearProfile: true,
        clearError: true,
      ),
    );
  }

  Future<void> signInWithPassword(String email, String password) => _runAuth(
    () => ref
        .read(authRepositoryProvider)
        .signInWithPassword(email: email, password: password),
  );

  Future<bool> signUp(String email, String password) async {
    var needsConfirmation = false;
    await _runAuth(() async {
      final response = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password);
      needsConfirmation = response.session == null;
      return response;
    });
    return needsConfirmation;
  }

  Future<void> signInWithGoogle() =>
      _runAuth(() => ref.read(authRepositoryProvider).signInWithGoogle());

  Future<void> sendPasswordReset(String email) => _runAuth(
    () => ref.read(authRepositoryProvider).sendPasswordReset(email),
    preserveMode: true,
  );

  Future<void> updatePassword(String password) => _runAuth(() async {
    final response = await ref
        .read(authRepositoryProvider)
        .updatePassword(password);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(passwordRecovery: false));
    }
    return response;
  }, preserveMode: true);

  Future<void> signOut() async {
    final current = state.value ?? await future;
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      await ref.read(authRepositoryProvider).signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeProfileKey);
      await ref.read(dataProfileControllerProvider.notifier).switchToGuest();
      state = AsyncData(
        current.copyWith(
          mode: AccountMode.local,
          accountChoiceComplete: true,
          clearUser: true,
          clearProfile: true,
          busy: false,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(current.copyWith(busy: false, error: error));
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    final current = state.value ?? await future;
    final userId = current.profileUserId;
    if (userId == null) return;
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      await ref.read(dataProfileControllerProvider.notifier).clearUser(userId);
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on Object {
        // The remote account is already gone; local teardown remains required.
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeProfileKey);
      state = AsyncData(
        current.copyWith(
          mode: AccountMode.local,
          clearUser: true,
          clearProfile: true,
          busy: false,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(current.copyWith(busy: false, error: error));
      rethrow;
    }
  }

  Future<void> importGuestData() async {
    final current = state.value ?? await future;
    final user = current.user;
    final client = ref.read(authRepositoryProvider).client;
    if (user == null || client == null || current.busy) return;
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    final guest = AppDatabase.open();
    try {
      await SyncEngine(
        database: guest,
        client: client,
        userId: user.id,
      ).importAll();
      await SyncEngine(
        database: ref.read(appDatabaseProvider),
        client: client,
        userId: user.id,
      ).synchronize();
      state = AsyncData(current.copyWith(busy: false, clearError: true));
    } on Object catch (error) {
      state = AsyncData(current.copyWith(busy: false, error: error));
      rethrow;
    } finally {
      await guest.close();
    }
  }

  Future<void> resolveGuestMerge({required bool merge}) async {
    final current = state.value ?? await future;
    final user = current.user;
    final client = ref.read(authRepositoryProvider).client;
    if (!current.mergeRequired || user == null || client == null) return;
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      if (merge) {
        await SyncEngine(
          database: ref.read(appDatabaseProvider),
          client: client,
          userId: user.id,
        ).importAll();
      }
      await ref
          .read(dataProfileControllerProvider.notifier)
          .switchToUser(user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeProfileKey, user.id);
      state = AsyncData(
        current.copyWith(
          mode: AccountMode.signedIn,
          busy: false,
          mergeRequired: false,
          clearError: true,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(current.copyWith(busy: false, error: error));
      rethrow;
    }
  }

  Future<void> _runAuth(
    Future<Object?> Function() action, {
    bool preserveMode = false,
  }) async {
    final current = state.value ?? await future;
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      await action();
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) await _activateUser(user);
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(busy: false, clearError: true));
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(
          busy: false,
          error: error,
          mode: preserveMode ? current.mode : null,
        ),
      );
      rethrow;
    }
  }

  Future<void> _onAuthChange(AuthState event) async {
    final user = event.session?.user;
    if (user != null) await _activateUser(user);
    if (user == null && event.event == AuthChangeEvent.signedOut) {
      final current = state.value;
      if (current?.isSignedIn == true && current?.busy != true) {
        state = AsyncData(
          current!.copyWith(
            mode: AccountMode.reconnectRequired,
            clearUser: true,
          ),
        );
      }
    }
    if (event.event == AuthChangeEvent.passwordRecovery) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(passwordRecovery: true));
      }
    }
  }

  Future<void> _activateUser(User user) async {
    final inFlight = _activation;
    if (inFlight != null && _activationUserId == user.id) {
      return inFlight;
    }
    final operation = _activateUserInner(user);
    _activation = operation;
    _activationUserId = user.id;
    try {
      await operation;
    } finally {
      if (identical(_activation, operation)) {
        _activation = null;
        _activationUserId = null;
      }
    }
  }

  Future<void> _activateUserInner(User user) async {
    final existing = state.value;
    if (existing?.isSignedIn == true &&
        existing?.user?.id == user.id &&
        (existing!.mergeRequired ||
            ref.read(dataProfileControllerProvider).userId == user.id)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_accountChoiceKey, true);
    final profile = ref.read(dataProfileControllerProvider);
    final client = ref.read(authRepositoryProvider).client;
    if (profile.isGuest && client != null) {
      final engine = SyncEngine(
        database: ref.read(appDatabaseProvider),
        client: client,
        userId: user.id,
      );
      final hasLocal = await engine.hasLocalData();
      if (hasLocal) {
        final hasCloud = await engine.hasCloudData();
        if (hasCloud) {
          state = AsyncData(
            AccountState(
              mode: AccountMode.signedIn,
              accountChoiceComplete: true,
              user: user,
              profileUserId: user.id,
              busy: false,
              mergeRequired: true,
            ),
          );
          return;
        }
        await engine.importAll();
      }
    }
    await prefs.setString(_activeProfileKey, user.id);
    await ref
        .read(dataProfileControllerProvider.notifier)
        .switchToUser(user.id);
    final current = state.value;
    state = AsyncData(
      AccountState(
        mode: AccountMode.signedIn,
        accountChoiceComplete: true,
        user: user,
        profileUserId: user.id,
        busy: current?.busy ?? false,
        mergeRequired: false,
      ),
    );
  }
}
