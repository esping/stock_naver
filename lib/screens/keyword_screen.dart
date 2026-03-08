import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/storage_service.dart';

class KeywordScreen extends StatefulWidget {
  const KeywordScreen({super.key});

  @override
  State<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends State<KeywordScreen> {
  List<Stock> _stocks = [];
  Set<String> _allowedSources = {};
  Set<String> _excludedKeywords = {};
  bool _newStockAdded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stocks = await StorageService.loadStocks();
    final allowed = await StorageService.loadAllowedSources();
    final excluded = await StorageService.loadExcludedKeywords();
    setState(() {
      _stocks = stocks;
      _allowedSources = allowed;
      _excludedKeywords = excluded;
    });
  }

  Future<void> _save() async {
    await StorageService.saveStocks(_stocks);
  }

  // ── 키워드 관련 ──────────────────────────────────────

  void _addKeyword(int stockIndex, String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    if (_stocks[stockIndex].keywords.contains(trimmed)) return;
    setState(() {
      _stocks[stockIndex] = _stocks[stockIndex].copyWith(
        keywords: [..._stocks[stockIndex].keywords, trimmed],
      );
    });
    _save();
  }

  void _removeKeyword(int stockIndex, int keywordIndex) {
    final updated = List<String>.from(_stocks[stockIndex].keywords)
      ..removeAt(keywordIndex);
    setState(() {
      _stocks[stockIndex] = _stocks[stockIndex].copyWith(keywords: updated);
    });
    _save();
    StorageService.cleanUpOrphanedNews(_stocks);
  }

  void _showAddKeywordDialog(int stockIndex) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_stocks[stockIndex].name} 키워드 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '키워드 입력'),
          onSubmitted: (v) {
            _addKeyword(stockIndex, v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _addKeyword(stockIndex, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('주제 추가'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '주제명 (예: 카카오, 인공지능)'),
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isEmpty) return;
            setState(() {
              _stocks.add(Stock(name: name, keywords: [name]));
              _newStockAdded = true;
            });
            _save();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _stocks.add(Stock(name: name, keywords: [name]));
                _newStockAdded = true;
              });
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _removeStock(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_stocks[index].name} 삭제'),
        content: const Text('이 주제를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _stocks.removeAt(index));
              _save();
              StorageService.cleanUpOrphanedNews(_stocks);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── 언론사 관련 (화이트리스트) ────────────────────────

  void _addSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || _allowedSources.contains(trimmed)) return;
    setState(() => _allowedSources.add(trimmed));
    StorageService.saveAllowedSources(_allowedSources);
  }

  void _removeSource(String source) {
    setState(() => _allowedSources.remove(source));
    StorageService.saveAllowedSources(_allowedSources);
  }

  void _showAddSourceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('언론사 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 한국경제, 조선일보'),
          onSubmitted: (v) {
            _addSource(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _addSource(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // ── 제외 키워드 관리 ──────────────────────────

  void _addExcludedKeyword(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || _excludedKeywords.contains(trimmed)) return;
    setState(() => _excludedKeywords.add(trimmed));
    StorageService.saveExcludedKeywords(_excludedKeywords);
  }

  void _removeExcludedKeyword(String keyword) {
    setState(() => _excludedKeywords.remove(keyword));
    StorageService.saveExcludedKeywords(_excludedKeywords);
  }

  void _showAddExcludedKeywordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제외 키워드 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 주가, 하락, 루머'),
          onSubmitted: (v) {
            _addExcludedKeyword(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _addExcludedKeyword(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _newStockAdded);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('설정'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _newStockAdded),
          ),
        ),
        body: ListView(
          children: [
            // 언론사 관리 섹션 (화이트리스트)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ExpansionTile(
                title: const Text(
                  '언론사 관리',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _allowedSources.isEmpty
                      ? '추가된 언론사 없음 (전체 언론사 표시)'
                      : '${_allowedSources.length}개 언론사만 표시',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                children: [
                  if (_allowedSources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        '언론사를 추가하면 해당 언론사 기사만 표시됩니다.\n추가하지 않으면 모든 언론사 기사가 표시됩니다.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...(_allowedSources.toList()..sort()).map(
                    (source) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.newspaper,
                        size: 18,
                        color: Colors.indigo,
                      ),
                      title: Text(source),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeSource(source),
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.indigo,
                    ),
                    title: const Text(
                      '언론사 추가',
                      style: TextStyle(color: Colors.indigo),
                    ),
                    onTap: _showAddSourceDialog,
                  ),
                ],
              ),
            ),

            // 제외 키워드 관리 섹션
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ExpansionTile(
                title: const Text(
                  '제외 키워드 관리',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _excludedKeywords.isEmpty
                      ? '제외할 키워드 없음'
                      : '${_excludedKeywords.length}개 키워드 제외 중',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                children: [
                  if (_excludedKeywords.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        '기사에서 제외하고 싶은 단어(예: 주가, 찌라시)를 추가하세요.\n해당 단어가 포함된 뉴스는 수집되지 않습니다.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...(_excludedKeywords.toList()..sort()).map(
                    (keyword) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.block,
                        size: 18,
                        color: Colors.deepOrange,
                      ),
                      title: Text(keyword),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeExcludedKeyword(keyword),
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.deepOrange,
                    ),
                    title: const Text(
                      '제외 키워드 추가',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                    onTap: _showAddExcludedKeywordDialog,
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '주제 관리',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            // 주제 목록
            ...List.generate(_stocks.length, (stockIndex) {
              final stock = _stocks[stockIndex];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  title: Text(
                    stock.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddKeywordDialog(stockIndex),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeStock(stockIndex),
                      ),
                    ],
                  ),
                  children: stock.keywords.asMap().entries.map((entry) {
                    return ListTile(
                      dense: true,
                      title: Text(entry.value),
                      trailing: stock.keywords.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  _removeKeyword(stockIndex, entry.key),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              );
            }),

            const SizedBox(height: 80),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddStockDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
