import 'package:flutter/material.dart';

import '../../../app/palette.dart';
import '../domain/footprint_item.dart';

extension FootprintRiskPresentation on FootprintRisk {
  Color get color => switch (this) {
    FootprintRisk.high => AppPalette.elevated,
    FootprintRisk.medium => AppPalette.warning,
    FootprintRisk.low => AppPalette.success,
  };

  Color get containerColor => switch (this) {
    FootprintRisk.high => AppPalette.elevatedContainer,
    FootprintRisk.medium => AppPalette.warningContainer,
    FootprintRisk.low => AppPalette.successContainer,
  };

  String get priorityLabel => switch (this) {
    FootprintRisk.high => 'Prioridad alta',
    FootprintRisk.medium => 'Prioridad media',
    FootprintRisk.low => 'Prioridad baja',
  };

  String get exposureLabel => switch (this) {
    FootprintRisk.high => 'Exposición alta',
    FootprintRisk.medium => 'Exposición moderada',
    FootprintRisk.low => 'Exposición baja',
  };
}
