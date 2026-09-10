import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Local profile navigation. The owning drawer closes before an action runs.
class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({
    required this.identity,
    this.historyCount = 0,
    this.onViewHistory,
    required this.caseCount,
    required this.onViewCases,
    required this.onHelp,
    this.accountName,
    this.onManageAccounts,
    this.isDemo = true,
    this.onViewSessions,
    this.onChangePassword,
    this.onViewCapabilities,
    super.key,
  });

  final int historyCount;
  final VoidCallback? onViewHistory;
  final String? identity;
  final String? accountName;
  final VoidCallback? onManageAccounts;
  final bool isDemo;
  final VoidCallback? onViewSessions;
  final VoidCallback? onChangePassword;
  final VoidCallback? onViewCapabilities;
  final int caseCount;
  final VoidCallback onViewCases;
  final VoidCallback onHelp;

  List<(String, IconData, String, VoidCallback?)> get _destinations => [
    ('Mi huella', Icons.fingerprint_rounded, 'profile-footprint', null),
    if (onViewHistory != null)
      (
        'Historial de escaneos ($historyCount)',
        Icons.history,
        'profile-history',
        onViewHistory,
      ),
    (
      'Casos del dispositivo ($caseCount)',
      Icons.folder_outlined,
      'profile-cases',
      onViewCases,
    ),
    if (onViewSessions != null)
      (
        'Sesiones activas',
        Icons.devices_rounded,
        'profile-sessions',
        onViewSessions,
      ),
    if (onChangePassword != null)
      (
        'Cambiar contraseña',
        Icons.password_rounded,
        'profile-password',
        onChangePassword,
      ),
    if (onViewCapabilities != null)
      (
        'Catálogo de escaneo',
        Icons.radar_rounded,
        'profile-capabilities',
        onViewCapabilities,
      ),
    if (onManageAccounts != null)
      (
        'Cerrar sesión',
        Icons.logout_rounded,
        'profile-accounts',
        onManageAccounts,
      ),
    ('Ayuda', Icons.help_outline_rounded, 'profile-help', onHelp),
  ];

  void _selectDestination(BuildContext context, int index) {
    Scaffold.of(context).closeDrawer();
    _destinations[index].$4?.call();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _buildDrawer(
      context,
      math.max(0.0, math.min(360.0, constraints.maxWidth - 24)),
    ),
  );

  Widget _buildDrawer(BuildContext context, double width) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profileIdentity = identity?.trim();
    final hasIdentity = profileIdentity != null && profileIdentity.isNotEmpty;
    final labelWidth = math.max(0.0, width - 92);
    final labelStyle = theme.textTheme.labelLarge!.copyWith(
      color: colors.onSurface,
    );
    final labels = _destinations.map((item) => item.$1).toList();

    // NavigationDrawer destinations have a fixed height and an unconstrained
    // label by default. Measure wrapped labels to retain their full text at
    // large text sizes while keeping every destination at least 56 px tall.
    var tileHeight = 56.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: labelWidth);
      tileHeight = math.max(tileHeight, painter.height + 24);
      painter.dispose();
    }

    Widget destinationLabel(int index) =>
        SizedBox(width: labelWidth, child: Text(labels[index]));

    return SizedBox(
      width: width,
      child: NavigationDrawerTheme(
        data: NavigationDrawerTheme.of(context).copyWith(
          tileHeight: tileHeight,
          indicatorSize: Size(width - 24, tileHeight - 8),
          labelTextStyle: WidgetStatePropertyAll(labelStyle),
        ),
        child: NavigationDrawer(
          backgroundColor: Color.alphaBlend(
            colors.primary.withValues(alpha: 0.04),
            colors.surface,
          ),
          elevation: 0,
          selectedIndex: 0,
          indicatorColor: colors.primaryContainer,
          onDestinationSelected: (index) => _selectDestination(context, index),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Tu espacio',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar perfil',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => Scaffold.of(context).closeDrawer(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: const Icon(Icons.person_outline_rounded, size: 30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (accountName != null) ...[
                    Text(
                      accountName!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Semantics(
                    container: true,
                    label: hasIdentity
                        ? 'Identidad: $profileIdentity'
                        : 'Sin identidad seleccionada',
                    excludeSemantics: true,
                    child: Text(
                      hasIdentity ? profileIdentity : 'Elige una identidad',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDemo
                        ? 'Cuenta de ejemplo'
                        : 'Sesión activa (PostgreSQL)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < _destinations.length; index++)
              NavigationDrawerDestination(
                key: Key(_destinations[index].$3),
                icon: Icon(_destinations[index].$2),
                label: destinationLabel(index),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Text(
                'Análisis de demostración. No realiza consultas reales.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
