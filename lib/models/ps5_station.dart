class Ps5Station {
  const Ps5Station({required this.label, this.maxControllers});

  final String label;
  final int? maxControllers;

  factory Ps5Station.fromJson(Map<String, dynamic> json) {
    final maxControllers = json['maxControllers'] ?? json['max_controllers'];
    return Ps5Station(
      label: json['label']?.toString() ?? '',
      maxControllers: maxControllers is num ? maxControllers.toInt() : null,
    );
  }
}
