import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:friend_private/backend/database/transcript_segment.dart';
import 'package:friend_private/backend/preferences.dart';
import 'package:instabug_flutter/instabug_flutter.dart';
import 'package:web_socket_channel/io.dart';

enum WebsocketConnectionStatus { notConnected, connected, failed, closed, error }

Future<IOWebSocketChannel?> _initWebsocketStream(
  void Function(List<TranscriptSegment>) onMessageReceived,
  VoidCallback onWebsocketConnectionSuccess,
  void Function(dynamic) onWebsocketConnectionFailed,
  void Function(int?, String?) onWebsocketConnectionClosed,
  void Function(dynamic) onWebsocketConnectionError,
  int sampleRate,
) async {
  debugPrint('Websocket Opening');
  final recordingsLanguage = SharedPreferencesUtil().recordingsLanguage;
  IOWebSocketChannel channel = IOWebSocketChannel.connect(
    Uri.parse(
        // '${Env.apiBaseUrl!.replaceAll('https', 'wss')}listen?language=$recordingsLanguage&uid=${SharedPreferencesUtil().uid}&sample_rate=$sampleRate'),
        'wss://5b37-107-3-134-29.ngrok-free.app/listen?language=$recordingsLanguage&uid=${SharedPreferencesUtil().uid}&sample_rate=$sampleRate'),
  );
  channel.ready.then((_) {
    channel.stream.listen(
      (event) {
        if (event == 'ping') return;
        final segments = jsonDecode(event);
        if (segments is List) {
          if (segments.isEmpty) return;
          onMessageReceived(segments.map((e) => TranscriptSegment.fromJson(e)).toList());
        } else {
          debugPrint(event.toString());
        }
      },
      onError: (err, stackTrace) {
        onWebsocketConnectionError(err); // error during connection
        CrashReporting.reportHandledCrash(err!, stackTrace, level: NonFatalExceptionLevel.warning);
      },
      onDone: (() {
        onWebsocketConnectionClosed(channel.closeCode, channel.closeReason);
      }),
      cancelOnError: true,
    );
  }).onError((err, stackTrace) {
    // no closing reason or code
    CrashReporting.reportHandledCrash(err!, stackTrace, level: NonFatalExceptionLevel.warning);
    onWebsocketConnectionFailed(err); // initial connection failed
  });

  try {
    await channel.ready;
    debugPrint('Websocket Opened');
    onWebsocketConnectionSuccess();
  } catch (err) {}
  return channel;
}

Future<IOWebSocketChannel?> streamingTranscript({
  required VoidCallback onWebsocketConnectionSuccess,
  required void Function(dynamic) onWebsocketConnectionFailed,
  required void Function(int?, String?) onWebsocketConnectionClosed,
  required void Function(dynamic) onWebsocketConnectionError,
  required void Function(List<TranscriptSegment>) onMessageReceived,
}) async {
  try {
    IOWebSocketChannel? channel = await _initWebsocketStream(
      onMessageReceived,
      onWebsocketConnectionSuccess,
      onWebsocketConnectionFailed,
      onWebsocketConnectionClosed,
      onWebsocketConnectionError,
      8000,
    );

    return channel;
  } catch (e) {
    debugPrint('Error receiving data: $e');
  } finally {}

  return null;
}
