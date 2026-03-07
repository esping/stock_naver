import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/storage_service.dart';
import '../services/rss_service.dart';

class KeywordScreen extends StatefulWidget {
  const KeywordScreen({super.key});

  @override
  State<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends State<KeywordScreen> {
  List<Stock> _stocks = [];
  Set<String> _allowedSources = {};
  Set<String> _enabledSections = {};
  bool _newStockAdded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stocks = await StorageService.loadStocks();
    final allowed = await StorageService.loadAllowedSources();
    final sections = await StorageService.loadEnabledSections();
    setState(() {
      _stocks = stocks;
      _allowedSources = allowed;
      _enabledSections = sections;
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
            setState(() {
              _stocks.add(Stock(name: name, keywords: [name]));
              _newStockAdded = true;
            });
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

  // ── 섹션 관련 ─────────────────────────────────────────

  void _toggleSection(String sectionKey) {
    setState(() {
      if (_enabledSections.contains(sectionKey)) {
        _enabledSections.remove(sectionKey);
      } else {
        _enabledSections.add(sectionKey);
      }
    });
    StorageService.saveEnabledSections(_enabledSections);
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
          // 섹션 선택 섹션
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text('뉴스 섹션', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _enabledSections.isEmpty
                    ? '섹션을 선택하면 해당 섹션 기사를 수집합니다'
                    : '${_enabledSections.length}개 섹션 수집 중',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    '선택한 섹션에서 종목 키워드가 포함된 기사를 수집합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                ...kGoogleNewsSections.entries.map((entry) {
                  final isEnabled = _enabledSections.contains(entry.key);
                  return CheckboxListTile(
                    dense: true,
                    value: isEnabled,
                    activeColor: Colors.indigo,
                    title: Text(entry.value),
                    onChanged: (_) => _toggleSection(entry.key),
                  );
                }),
              ],
            ),
          ),

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
    ),
    );
  }
}
