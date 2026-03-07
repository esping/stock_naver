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
  Set<String> _discoveredCategories = {};
  Set<String> _excludedCategories = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stocks = await StorageService.loadStocks();
    final allowed = await StorageService.loadAllowedSources();
    final discoveredCat = await StorageService.loadDiscoveredCategories();
    final excludedCat = await StorageService.loadExcludedCategories();
    setState(() {
      _stocks = stocks;
      _allowedSources = allowed;
      _discoveredCategories = discoveredCat;
      _excludedCategories = excludedCat;
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
    final updated = List<String>.from(_stocks[stockIndex].keywords)..removeAt(keywordIndex);
    setState(() {
      _stocks[stockIndex] = _stocks[stockIndex].copyWith(keywords: updated);
    });
    _save();
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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
        title: const Text('종목 추가'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '종목명 (예: 카카오)'),
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isEmpty) return;
            setState(() => _stocks.add(Stock(name: name, keywords: [name])));
            _save();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() => _stocks.add(Stock(name: name, keywords: [name])));
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
        content: const Text('이 종목을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              setState(() => _stocks.removeAt(index));
              _save();
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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

  // ── 카테고리 관련 ─────────────────────────────────────

  void _toggleExcludeCategory(String category) {
    setState(() {
      if (_excludedCategories.contains(category)) {
        _excludedCategories.remove(category);
      } else {
        _excludedCategories.add(category);
      }
    });
    StorageService.saveExcludedCategories(_excludedCategories);
  }

  // ── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 언론사 관리 섹션 (화이트리스트)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: const Text('언론사 관리', style: TextStyle(fontWeight: FontWeight.bold)),
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
                ...(_allowedSources.toList()..sort()).map((source) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.newspaper, size: 18, color: Colors.indigo),
                      title: Text(source),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () => _removeSource(source),
                      ),
                    )),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add, size: 18, color: Colors.indigo),
                  title: const Text('언론사 추가', style: TextStyle(color: Colors.indigo)),
                  onTap: _showAddSourceDialog,
                ),
              ],
            ),
          ),

          // 카테고리 관리 섹션
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: const Text('카테고리 관리', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _discoveredCategories.isEmpty
                    ? '뉴스 수집 후 자동으로 목록이 채워집니다'
                    : '${_discoveredCategories.length}개 발견 · ${_excludedCategories.length}개 제외 중',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: [
                if (_discoveredCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '새로고침으로 뉴스를 수집하면\n카테고리 목록이 자동으로 나타납니다.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...(_discoveredCategories.toList()..sort()).map((category) {
                    final isExcluded = _excludedCategories.contains(category);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.label_outline,
                        size: 18,
                        color: isExcluded ? Colors.grey : Colors.indigo,
                      ),
                      title: Text(
                        category,
                        style: TextStyle(
                          color: isExcluded ? Colors.grey : null,
                          decoration: isExcluded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      trailing: Switch(
                        value: !isExcluded,
                        activeColor: Colors.indigo,
                        onChanged: (_) => _toggleExcludeCategory(category),
                      ),
                    );
                  }),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('종목 관리', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          // 종목 목록
          ...List.generate(_stocks.length, (stockIndex) {
            final stock = _stocks[stockIndex];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ExpansionTile(
                title: Text(stock.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddKeywordDialog(stockIndex),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                            onPressed: () => _removeKeyword(stockIndex, entry.key),
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
    );
  }
}
