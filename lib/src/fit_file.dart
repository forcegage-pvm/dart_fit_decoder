/// Represents a decoded FIT file with header and messages.
library;

import 'fit_data_message.dart';
import 'fit_header.dart';
import 'fit_message.dart';
import 'fit_message_type.dart';

/// Represents a complete decoded FIT file.
class FitFile {
  /// FIT file header.
  final FitHeader header;

  /// All messages in the file (definition and data).
  final List<FitMessage> messages;

  /// CRC value from end of file.
  final int? fileCrc;

  const FitFile({
    required this.header,
    required this.messages,
    this.fileCrc,
  });

  /// Get all data messages (excluding definitions).
  List<FitDataMessage> get dataMessages {
    return messages.whereType<FitDataMessage>().toList();
  }

  /// Get all record messages (GPS data, HR, power, etc.).
  List<FitDataMessage> getRecordMessages() {
    return dataMessages.where((msg) => msg.globalMessageNumber == FitMessageType.record).toList();
  }

  /// Get all lap messages.
  List<FitDataMessage> getLapMessages() {
    return dataMessages.where((msg) => msg.globalMessageNumber == FitMessageType.lap).toList();
  }

  /// Get all session messages.
  List<FitDataMessage> getSessionMessages() {
    return dataMessages.where((msg) => msg.globalMessageNumber == FitMessageType.session).toList();
  }

  /// Get messages of a specific type by global message number.
  List<FitDataMessage> getMessagesByType(int globalMessageNumber) {
    return dataMessages.where((msg) => msg.globalMessageNumber == globalMessageNumber).toList();
  }

  /// Get messages of a specific type by name.
  List<FitDataMessage> getMessagesByName(String name) {
    return dataMessages.where((msg) => msg.messageName == name).toList();
  }

  @override
  String toString() {
    final recordCount = getRecordMessages().length;
    final lapCount = getLapMessages().length;
    final sessionCount = getSessionMessages().length;

    return 'FitFile('
        'protocol=${header.protocolVersionDecimal.toStringAsFixed(1)}, '
        'profile=${header.profileVersionDecimal.toStringAsFixed(2)}, '
        'messages=${messages.length}, '
        'records=$recordCount, '
        'laps=$lapCount, '
        'sessions=$sessionCount'
        ')';
  }
}
