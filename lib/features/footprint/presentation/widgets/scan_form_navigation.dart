import 'dart:async';

import 'package:flutter/material.dart';

import '../../../accounts/domain/identity_profile.dart';
import '../../../accounts/presentation/identity_profile_controller.dart';
import '../footprint_controller.dart';
import 'scan_bottom_sheet.dart';

void openScanForm(
  BuildContext context,
  FootprintController controller, {
  IdentityProfileController? identityController,
  String fallbackIdentity = '',
}) {
  if (controller.isLoading) return;
  final profile = identityController?.profile;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ScanBottomSheet(
      initialIdentity:
          profile?.mainIdentifier ??
          controller.profile?.targetIdentity ??
          fallbackIdentity,
      email: profile?.associatedEmail,
      phone: profile?.phone,
      aliases: profile?.associatedUsernames ?? const [],
      onScan: (input) async {
        if (identityController != null) {
          final saved = await identityController.save(
            IdentityProfile(
              accountId: identityController.accountId,
              mainIdentifier: input.email,
              associatedEmail: input.email,
              phone: input.phone,
              associatedUsernames: input.aliases,
              fullName: profile?.fullName,
              consentSelfAudit: true,
              createdAt: profile?.createdAt ?? DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (!saved) throw StateError('Identity persistence failed');
        }
        // The existing API accepts phone as primary, email and aliases as associated inputs.
        unawaited(
          controller.scanIdentity(
            input.phone,
            associatedUsernames: input.aliases,
            associatedEmail: input.email,
          ),
        );
      },
    ),
  );
}
