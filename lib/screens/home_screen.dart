import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_item.dart';
import '../models/stock.dart';
import '../services/rss_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'keyword_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Stock> _stocks = [];
  Map<String, List<NewsItem>> _newsByStock = {};
  bool _loading = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stocks = await StorageService.loadStocks();
    final savedNews = await StorageService.loadNews();

    final byStock = <String, List<NewsItem>>{};
    for (final stock in stocks) {
      byStock[stock.name] =
          savedNews.where((n) => n.stockName == stock.name).toList();
    }

    setState(() {
      _stocks = stocks;
      _newsByStock = byStock;
      _tabController?.dispose();
      _tabController = TabController(length: stocks.length, vsync: this);
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);

    final stocks = await StorageService.loadStocks();
    final prevNews = await StorageService.loadNews();
    final prevTitles = prevNews.map((n) => n.title).toSet();

    final allowedSources = await StorageService.loadAllowedSources();
    final excludedKeywords = await StorageService.loadExcludedKeywords();
    final freshNews = await RssService.fetchAllNews(stocks, allowedSources: allowedSources, excludedKeywords: excludedKeywords);

    final mergedNews = StorageService.mergeAndFilter(
      freshNews, prevNews,
      allowedSources: allowedSources,
    );
    await StorageService.saveNews(mergedNews);

    // 새 기사 집계 후 통합 알림 1건 (실제 저장된 기사 기준)
    final newArticles = mergedNews.where((n) => !prevTitles.contains(n.title)).toList();
    final newKeywordCount = stocks
        .where((s) => newArticles.any((n) => n.stockName == s.name))
        .length;
    await NotificationService.showSummary(newKeywordCount, newArticles.length);

    final byStock = <String, List<NewsItem>>{};
    for (final stock in stocks) {
      byStock[stock.name] =
          mergedNews.where((n) => n.stockName == stock.name).toList();
    }

    setState(() {
      _stocks = stocks;
      _newsByStock = byStock;
      _loading = false;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _formatDateLabel(String key) {
    final parts = key.split('-');
    return '${parts[1]}월 ${parts[2]}일';
  }

  void _showArticlesByDate(
      String stockName, String dateKey, List<NewsItem> articles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                '$stockName · ${_formatDateLabel(dateKey)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: articles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = articles[i];
                  return ListTile(
                    title: Text(item.title,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${item.source}  ·  ${_formatTime(item.publishedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () => _openUrl(item.link),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTab(Stock stock) {
    final news = _newsByStock[stock.name] ?? [];

    // 날짜별 그룹화
    final groupedByDate = <String, List<NewsItem>>{};
    for (final item in news) {
      final key = _dateKey(item.publishedAt);
      groupedByDate.putIfAbsent(key, () => []).add(item);
    }
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 키워드 섹션
          const Text('키워드',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: stock.keywords
                .map((kw) => Chip(
                      label: Text(kw,
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.indigo.shade50,
                      side: BorderSide(color: Colors.indigo.shade200),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),

          // 날짜별 기사 섹션
          const Text('날짜별 기사',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),

          if (news.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                  child: Text('뉴스를 수집하려면 새로고침을 눌러주세요')),
            )
          else
            ...sortedDates.map((dateKey) {
              final articles = groupedByDate[dateKey]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today,
                      size: 20, color: Colors.indigo),
                  title: Text(_formatDateLabel(dateKey)),
                  trailing: Text('${articles.length}건',
                      style: const TextStyle(color: Colors.grey)),
                  onTap: () =>
                      _showArticlesByDate(stock.name, dateKey, articles),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 주식 뉴스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final newStockAdded = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const KeywordScreen()));
              if (newStockAdded == true) {
                _refresh();
              } else {
                _loadData();
              }
            },
          ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: _stocks.isEmpty || _tabController == null
            ? null
            : TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabs: _stocks.map((s) => Tab(text: s.name)).toList(),
              ),
      ),
      body: _stocks.isEmpty || _tabController == null
          ? const Center(child: Text('키워드를 추가해주세요'))
          : TabBarView(
              controller: _tabController!,
              children: _stocks.map(_buildStockTab).toList(),
            ),
    );
  }
}
