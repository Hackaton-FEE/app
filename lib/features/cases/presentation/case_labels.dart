import 'package:flutter/material.dart';

import '../domain/privacy_case.dart';

extension CaseCategoryPresentation on CaseCategory {
  String get label => switch (this) {
    CaseCategory.personalData => 'Datos personales',
    CaseCategory.impersonation => 'Suplantación de identidad',
    CaseCategory.intimateContent => 'Contenido íntimo',
    CaseCategory.other => 'Otro',
  };

  IconData get icon => switch (this) {
    CaseCategory.personalData => Icons.badge_outlined,
    CaseCategory.impersonation => Icons.person_search_outlined,
    CaseCategory.intimateContent => Icons.lock_outline,
    CaseCategory.other => Icons.description_outlined,
  };
}

extension CaseStatusPresentation on CaseStatus {
  String get label => switch (this) {
    CaseStatus.draft => 'Borrador',
    CaseStatus.archived => 'Archivado',
  };
}
