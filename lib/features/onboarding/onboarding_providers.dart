import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingVersionKey = 'onboarding.version';
const _checklistDismissedKey = 'onboarding.checklistDismissed';
const _demoManifestKey = 'onboarding.demoManifest';
const currentOnboardingVersion = 1;

class OnboardingState {
  const OnboardingState({
    required this.version,
    required this.checklistDismissed,
    this.demoManifest,
  });

  final int version;
  final bool checklistDismissed;
  final DemoDataManifest? demoManifest;

  bool get setupComplete => version >= currentOnboardingVersion;

  OnboardingState copyWith({
    int? version,
    bool? checklistDismissed,
    DemoDataManifest? demoManifest,
    bool clearDemoManifest = false,
  }) => OnboardingState(
    version: version ?? this.version,
    checklistDismissed: checklistDismissed ?? this.checklistDismissed,
    demoManifest: clearDemoManifest
        ? null
        : (demoManifest ?? this.demoManifest),
  );
}

class DemoDataManifest {
  const DemoDataManifest({
    required this.workspaceId,
    required this.projectId,
    required this.contactId,
    required this.eventId,
    required this.taskId,
    required this.noteId,
    required this.billableId,
  });

  final String workspaceId;
  final String projectId;
  final String contactId;
  final String eventId;
  final String taskId;
  final String noteId;
  final String billableId;

  Map<String, Object?> toJson() => {
    'workspaceId': workspaceId,
    'projectId': projectId,
    'contactId': contactId,
    'eventId': eventId,
    'taskId': taskId,
    'noteId': noteId,
    'billableId': billableId,
  };

  factory DemoDataManifest.fromJson(Map<String, Object?> json) =>
      DemoDataManifest(
        workspaceId: json['workspaceId']! as String,
        projectId: json['projectId']! as String,
        contactId: json['contactId']! as String,
        eventId: json['eventId']! as String,
        taskId: json['taskId']! as String,
        noteId: json['noteId']! as String,
        billableId: json['billableId']! as String,
      );
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final rawManifest = prefs.getString(_demoManifestKey);
    DemoDataManifest? manifest;
    if (rawManifest != null) {
      try {
        manifest = DemoDataManifest.fromJson(
          (jsonDecode(rawManifest) as Map).cast<String, Object?>(),
        );
      } on FormatException {
        await prefs.remove(_demoManifestKey);
      } on TypeError {
        await prefs.remove(_demoManifestKey);
      }
    }
    return OnboardingState(
      version: prefs.getInt(_onboardingVersionKey) ?? 0,
      checklistDismissed: prefs.getBool(_checklistDismissedKey) ?? false,
      demoManifest: manifest,
    );
  }

  Future<void> completeSetup() async {
    final previous = state.value ?? await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_onboardingVersionKey, currentOnboardingVersion);
    state = AsyncData(previous.copyWith(version: currentOnboardingVersion));
  }

  Future<void> dismissChecklist() async {
    final previous = state.value ?? await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checklistDismissedKey, true);
    state = AsyncData(previous.copyWith(checklistDismissed: true));
  }

  Future<void> setDemoManifest(DemoDataManifest manifest) async {
    final previous = state.value ?? await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_demoManifestKey, jsonEncode(manifest.toJson()));
    state = AsyncData(previous.copyWith(demoManifest: manifest));
  }

  Future<void> clearDemoManifest() async {
    final previous = state.value ?? await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoManifestKey);
    state = AsyncData(previous.copyWith(clearDemoManifest: true));
  }
}
