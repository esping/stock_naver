import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/notification_service.dart';
import 'services/rss_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

const _bgTaskName = 'stockNewsRefresh';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // 휴면 시간 (02:00 ~ 08:00) 수집 건너뜀
    final hour = DateTime.now().hour;
    if (hour >= 2 && hour < 8) return true;

    await NotificationService.init();
    final stocks = await StorageService.loadStocks();
    final prevNews = await StorageService.loadNews();
    final prevTitles = prevNews.map((n) => n.title).toSet();

    final enabledSections = await StorageService.loadEnabledSections();
    final freshNews = await RssService.fetchAllNews(stocks, enabledSections: enabledSections);

    final allowedSources = await StorageService.loadAllowedSources();
    final mergedNews = StorageService.mergeAndFilter(
      freshNews, prevNews,
      allowedSources: allowedSources,
    );
    await StorageService.saveNews(mergedNews);

    // 새 기사 집계 후 통합 알림 1건
    final newArticles = freshNews.where((n) => !prevTitles.contains(n.title)).toList();
    final newKeywordCount = stocks
        .where((s) => newArticles.any((n) => n.stockName == s.name))
        .length;
    await NotificationService.showSummary(newKeywordCount, newArticles.length);
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _bgTaskName,
    _bgTaskName,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
  runApp(const MyStockApp());
}

class MyStockApp extends StatelessWidget {
  const MyStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내 주식 뉴스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
