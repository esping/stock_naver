import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
  }

  // 새 기사가 있을 때만 통합 알림 1건 발송
  // keywordCount: 새 기사가 있는 키워드(종목) 수, articleCount: 전체 새 기사 수
  static Future<void> showSummary(int keywordCount, int articleCount) async {
    if (articleCount == 0) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'stock_news',
        '주식 뉴스',
        channelDescription: '보유 종목 뉴스 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.show(
      0,
      '내 주식 뉴스',
      '$keywordCount개 종목, $articleCount개 기사 수집',
      details,
    );
  }
}
