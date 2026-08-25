enum ServiceType {
  ps5,
  vr,
  simulator,
  theatre;

  static ServiceType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'vr':
        return ServiceType.vr;
      case 'simulator':
        return ServiceType.simulator;
      case 'theatre':
      case 'theater':
        return ServiceType.theatre;
      default:
        return ServiceType.ps5;
    }
  }

  String get shortLabel => switch (this) {
    ServiceType.ps5 => 'PS5',
    ServiceType.vr => 'VR',
    ServiceType.simulator => 'SIM',
    ServiceType.theatre => 'THEATRE',
  };
}
