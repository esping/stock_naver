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

class _HomeScreenState extends State<HomeScreen> {
  List<Stock> _stocks = [];
  Map<String, List<NewsItem>> _newsByStock = {};
  Set<String> _readLinks = {};
  bool _loading = false;
  String? _selectedStock;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final stocks = await StorageService.loadStocks();
    final savedNews = await StorageService.loadNews();
    final readLinks = await StorageService.loadReadLinks();

    final byStock = <String, List<NewsItem>>{};
    for (final stock in stocks) {
      byStock[stock.name] = savedNews
          .where((n) => n.stockName == stock.name)
          .toList();
    }

    setState(() {
      _stocks = stocks;
      _newsByStock = byStock;
      _readLinks = readLinks;
      if (_stocks.isNotEmpty && _selectedStock == null) {
        _selectedStock = _stocks.first.name;
      } else if (_stocks.isNotEmpty &&
          !_stocks.any((s) => s.name == _selectedStock)) {
        _selectedStock = _stocks.first.name;
      } else if (_stocks.isEmpty) {
        _selectedStock = null;
      }
    });
  }

  Future<void> _refresh({Stock? targetStock}) async {
    if (_loading) return;
    setState(() => _loading = true);

    final dtNow = DateTime.now();
    final dtYesterday = dtNow.subtract(const Duration(days: 1));
    final dateToday =
        '${dtNow.year}-${dtNow.month.toString().padLeft(2, '0')}-${dtNow.day.toString().padLeft(2, '0')}';
    final dateYesterday =
        '${dtYesterday.year}-${dtYesterday.month.toString().padLeft(2, '0')}-${dtYesterday.day.toString().padLeft(2, '0')}';

    // 중복 체크를 위해 전체가 아닌 어제와 오늘의 기사만 로드
    final allStocks = await StorageService.loadStocks();
    final stocksToFetch = targetStock != null ? [targetStock] : allStocks;

    final prevNews = await StorageService.loadNews(
      targetDates: [dateToday, dateYesterday],
    );
    final readLinks = await StorageService.loadReadLinks();
    final prevTitles = prevNews.map((n) => n.title).toSet();

    final allowedSources = await StorageService.loadAllowedSources();
    final excludedKeywords = await StorageService.loadExcludedKeywords();
    final freshNews = await RssService.fetchAllNews(
      stocksToFetch,
      allowedSources: allowedSources,
      excludedKeywords: excludedKeywords,
    );

    final mergedNews = StorageService.mergeAndFilter(
      freshNews,
      prevNews,
      allowedSources: allowedSources,
    );
    await StorageService.saveNews(mergedNews);

    // 새 기사 집계 후 통합 알림 1건 (실제 저장된 기사 기준)
    final newArticles = mergedNews
        .where((n) => !prevTitles.contains(n.title))
        .toList();
    final newKeywordCount = allStocks
        .where((s) => newArticles.any((n) => n.stockName == s.name))
        .length;
    if (newArticles.isNotEmpty) {
      await NotificationService.showSummary(
        newKeywordCount,
        newArticles.length,
      );
    }

    final byStock = <String, List<NewsItem>>{};
    for (final stock in allStocks) {
      byStock[stock.name] = mergedNews
          .where((n) => n.stockName == stock.name)
          .toList();
    }

    setState(() {
      _stocks = allStocks;
      _newsByStock = byStock;
      _readLinks = readLinks;
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
    String stockName,
    String dateKey,
    List<NewsItem> articles,
  ) {
    bool hasNew = false;
    for (final item in articles) {
      if (_readLinks.add(item.link)) {
        hasNew = true;
      }
    }
    if (hasNew) {
      setState(() {});
      StorageService.saveReadLinks(_readLinks);
    }

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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                    title: Text(
                      item.title,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${item.source}  ·  ${_formatTime(item.publishedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildSelectedStockNews() {
    if (_selectedStock == null || _stocks.isEmpty) {
      return const Center(child: Text('키워드를 추가해주세요'));
    }

    final stock = _stocks.firstWhere(
      (s) => s.name == _selectedStock,
      orElse: () => _stocks.first,
    );
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
      onRefresh: () async {
        if (_selectedStock != null) {
          final target = _stocks.firstWhere((s) => s.name == _selectedStock);
          await _refresh(targetStock: target);
        } else {
          await _refresh();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 날짜별 기사 섹션
          const Text(
            '날짜별 기사',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          if (news.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('뉴스를 수집하려면 새로고침을 눌러주세요')),
            )
          else
            ...sortedDates.map((dateKey) {
              final articles = groupedByDate[dateKey]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.indigo,
                  ),
                  title: Text(_formatDateLabel(dateKey)),
                  trailing: Text(
                    '${articles.length}건',
                    style: const TextStyle(color: Colors.grey),
                  ),
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
              final newStockAdded = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const KeywordScreen()),
              );
              if (newStockAdded == true) {
                _refresh();
              } else {
                _loadData();
              }
            },
          ),
          IconButton(
            tooltip: '현재 종목 새로고침',
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedStock != null) {
                final target = _stocks.firstWhere(
                  (s) => s.name == _selectedStock,
                );
                _refresh(targetStock: target);
              }
            },
          ),
          IconButton(
            tooltip: '전체 새로고침',
            icon: _loading
                ? const SizedBox(width: 20, height: 20)
                : const Icon(Icons.sync),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: _stocks.isEmpty
          ? const Center(child: Text('키워드를 추가해주세요'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.white,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: -4,
                    children: _stocks.map((s) {
                      final isSelected = s.name == _selectedStock;

                      // 해당 종목의 전체 뉴스 중 안 읽은 기사가 있는지 검사
                      final stockNews = _newsByStock[s.name] ?? [];
                      final hasUnread = stockNews.any(
                        (n) => !_readLinks.contains(n.link),
                      );

                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.name),
                            if (hasUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedStock = s.name);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(child: _buildSelectedStockNews()),
              ],
            ),
    );
  }
}
