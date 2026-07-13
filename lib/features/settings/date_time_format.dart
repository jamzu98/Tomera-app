import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'settings_providers.dart';

bool uses24HourTime(BuildContext context, WidgetRef ref) => ref
    .watch(timeFormatSettingProvider)
    .resolveUses24Hour(
      systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
    );

bool readUses24HourTime(BuildContext context, WidgetRef ref) => ref
    .read(timeFormatSettingProvider)
    .resolveUses24Hour(
      systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
    );

DateFormat appTimeFormat(BuildContext context, WidgetRef ref) =>
    uses24HourTime(context, ref) ? DateFormat.Hm() : DateFormat.jm();

String formatTimeOfDay(BuildContext context, WidgetRef ref, TimeOfDay value) =>
    appTimeFormat(
      context,
      ref,
    ).format(DateTime(2000, 1, 1, value.hour, value.minute));

TransitionBuilder appTimePickerBuilder(BuildContext context, WidgetRef ref) {
  final uses24Hour = readUses24HourTime(context, ref);
  return (pickerContext, child) => MediaQuery(
    data: MediaQuery.of(
      pickerContext,
    ).copyWith(alwaysUse24HourFormat: uses24Hour),
    child: child ?? const SizedBox.shrink(),
  );
}

String syncfusionTimeFormat(BuildContext context, WidgetRef ref) =>
    uses24HourTime(context, ref) ? 'HH:mm' : 'h a';
