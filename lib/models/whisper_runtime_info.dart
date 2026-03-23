import 'package:equatable/equatable.dart';

class WhisperRuntimeInfo extends Equatable {
  final String modeLabel;
  final String? deviceName;
  final int numThreads;
  final String? note;

  const WhisperRuntimeInfo({
    required this.modeLabel,
    this.deviceName,
    this.numThreads = 4,
    this.note,
  });

  String get technicalSummary {
    final List<String> parts = <String>[
      modeLabel,
      if (deviceName != null && deviceName!.trim().isNotEmpty)
        deviceName!.trim(),
      'threads=$numThreads',
    ];
    return parts.join(' | ');
  }

  @override
  List<Object?> get props => <Object?>[
    modeLabel,
    deviceName,
    numThreads,
    note,
  ];
}
