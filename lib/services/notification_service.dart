import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
  }

  // 새 기사가 있을 때만 통합 알림 1건 발송
  static Future<void> showSummary(Map<String, int> newArticleCounts) async {
    if (newArticleCounts.isEmpty) return;

    final totalCount = newArticleCounts.values.fold(0, (sum, count) => sum + count);
    final message = newArticleCounts.entries
        .map((e) => '[${e.key}] ${e.value}건')
        .join('\n');

    final bigTextStyle = BigTextStyleInformation(
      message,
      contentTitle: '내 주식 뉴스 ($totalCount건 수집)',
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'stock_news',
        '주식 뉴스',
        channelDescription: '보유 종목 뉴스 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: bigTextStyle,
      ),
    );

    await _plugin.show(
      0,
      '내 주식 뉴스 ($totalCount건 수집)',
      message,
      details,
    );
  }
}
