import 'dart:io';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';

void main() {
  final bytes = File('test/fixtures/activity_small.fit').readAsBytesSync();
  final decoder = FitDecoder(bytes);
  final fitFile = decoder.decode();

  final laps = fitFile.getLapMessages();
  print('First lap fields:');
  for (final field in laps.first.fields) {
    if (field.name != null && (field.name!.contains('heart') || field.name!.contains('sport'))) {
      print('  ${field.name}: ${field.value} (field#${field.fieldNumber})');
    }
  }

  print('\nSession fields:');
  final sessions = fitFile.getSessionMessages();
  for (final field in sessions.first.fields) {
    if (field.name != null && (field.name!.contains('heart') || field.name!.contains('sport'))) {
      print('  ${field.name}: ${field.value} (field#${field.fieldNumber})');
    }
  }

  print('\nFirst record developer fields count: ${fitFile.getRecordMessages().first.developerFields.length}');
}
