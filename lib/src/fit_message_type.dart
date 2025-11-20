/// FIT message types (global message numbers).
library;

/// Common FIT message types with their global message numbers.
class FitMessageType {
  static const int fileId = 0;
  static const int capabilities = 1;
  static const int deviceSettings = 2;
  static const int userProfile = 3;
  static const int hrmProfile = 4;
  static const int sdmProfile = 5;
  static const int bikeProfile = 6;
  static const int zones = 7;
  static const int session = 18;
  static const int lap = 19;
  static const int record = 20;
  static const int event = 21;
  static const int deviceInfo = 23;
  static const int workout = 26;
  static const int workoutStep = 27;
  static const int schedule = 28;
  static const int activity = 34;
  static const int fileCreator = 49;
  static const int fieldDescription = 206; // 0xCE - Developer fields
  static const int developerDataId = 207; // 0xCF - Developer data IDs

  /// Get message type name from global message number.
  static String? getName(int messageNumber) {
    switch (messageNumber) {
      case 0:
        return 'file_id';
      case 1:
        return 'capabilities';
      case 2:
        return 'device_settings';
      case 3:
        return 'user_profile';
      case 4:
        return 'hrm_profile';
      case 5:
        return 'sdm_profile';
      case 6:
        return 'bike_profile';
      case 7:
        return 'zones';
      case 18:
        return 'session';
      case 19:
        return 'lap';
      case 20:
        return 'record';
      case 21:
        return 'event';
      case 23:
        return 'device_info';
      case 26:
        return 'workout';
      case 27:
        return 'workout_step';
      case 28:
        return 'schedule';
      case 34:
        return 'activity';
      case 49:
        return 'file_creator';
      case 206:
        return 'field_description';
      case 207:
        return 'developer_data_id';
      default:
        return null;
    }
  }

  /// Check if message type is a developer field definition.
  static bool isDeveloperFieldMessage(int messageNumber) {
    return messageNumber == fieldDescription || messageNumber == developerDataId;
  }
}
