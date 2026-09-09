import 'package:flutter/material.dart';

import '../domain/footprint_item.dart';

extension FootprintRiskPresentation on FootprintRisk {
  Color get color => switch (this) {
    FootprintRisk.high => const Color(0xFF9C4635),
    FootprintRisk.medium => const Color(0xFF866117),
    FootprintRisk.low => const Color(0xFF35634A),
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
