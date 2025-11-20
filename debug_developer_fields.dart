import 'dart:io';

import 'lib/dart_fit_decoder.dart';

void main() {
  final file = File('test/fixtures/activity_recent.fit');
  final bytes = file.readAsBytesSync();

  final decoder = FitDecoder(bytes);
  final fitFile = decoder.decode();

  // Check for field_description messages
  final fieldDescriptions = fitFile.getMessagesByType(206);
  print('Field description messages: ${fieldDescriptions.length}');

  if (fieldDescriptions.isNotEmpty) {
    print('\nFirst field description:');
    for (final field in fieldDescriptions.first.fields) {
      print('  ${field.name ?? "field#${field.fieldNumber}"}: ${field.value}');
    }
  }

  // Check for developer_data_id messages
  final devDataIds = fitFile.getMessagesByType(207);
  print('\nDeveloper data ID messages: ${devDataIds.length}');

  // Check records for developer fields
  final records = fitFile.getRecordMessages();
  print('\nTotal records: ${records.length}');

  // Find first record with developer fields
  var foundDev = false;
  for (var i = 0; i < records.length && !foundDev; i++) {
    final record = records[i];
    if (record.developerFields.isNotEmpty) {
      print('\nFirst record with developer fields (record #$i):');
      print('  Standard fields: ${record.fields.length}');
      print('  Developer fields: ${record.developerFields.length}');

      for (final devField in record.developerFields) {
        print('    Field #${devField.fieldNumber} (${devField.name ?? "unknown"}): ${devField.value} ${devField.units ?? ""}');
      }
      foundDev = true;
    }
  }

  if (!foundDev) {
    print('\nNo records found with developer fields');
    print('Checking first few records:');
    for (var i = 0; i < 3 && i < records.length; i++) {
      final record = records[i];
      print('  Record #$i: ${record.fields.length} fields, ${record.developerFields.length} dev fields');
    }
  }
}
