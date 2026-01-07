import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:testing_app/features/operations/presentation/views/operations_screen.dart';
import 'package:testing_app/models/operation_type.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../models/operation_product.dart';
import '../boxes/hive_boxes.dart';

class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({super.key});

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Box<OperationProduct> _opProductBox;

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _loading = true;

  // Фильтры
  String? _selectedOperationType;
  int? _selectedYear;
  String? _selectedCounteragent;

  List<String> _operationTypes = [];
  List<int> _years = [];
  List<String> _counteragents = [];

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _initHive() async {
    _opProductBox = await Hive.openBox<OperationProduct>(
      HiveBoxes.operationProducts,
    );
    _loadLocalHistory();
  }

  void _loadLocalHistory() {
    List<Map<String, dynamic>> allHistory = [];
    Set<String> opTypes = {};
    Set<int> yearsSet = {};
    Set<String> counteragentsSet = {};

    for (var opProduct in _opProductBox.values) {
      final product = opProduct.product;
      final op = opProduct.operation;
      if (product == null) continue;

      DateTime? date;
      if (opProduct.docDate != null && opProduct.docDate!.isNotEmpty) {
        try {
          date = DateTime.tryParse(opProduct.docDate!);
        } catch (_) {
          date = null;
        }
      }

      String typeName = 'Неизвестная операция';
      if (op != null && Hive.isBoxOpen(HiveBoxes.operationTypes)) {
        final opTypeBox = Hive.box<OperationType>(HiveBoxes.operationTypes);
        final opType = opTypeBox.get(op.typeId);
        if (opType != null) typeName = opType.name;
      }

      opTypes.add(typeName);
      if (date != null) yearsSet.add(date.year);
      if ((opProduct.counteragent ?? '').isNotEmpty) {
        counteragentsSet.add(opProduct.counteragent!);
      }

      allHistory.add({
        'operation': typeName,
        'product': product.name,
        'quantity': opProduct.quantity ?? 0,
        'counteragent': opProduct.counteragent ?? 'Не указан',
        'date': date,
      });
    }

    allHistory.sort((a, b) {
      final dateA = a['date'] as DateTime?;
      final dateB = b['date'] as DateTime?;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    setState(() {
      _history = allHistory;
      _filteredHistory = List.from(_history);
      _operationTypes = opTypes.toList()..sort();
      _years = yearsSet.toList()..sort((a, b) => b.compareTo(a));
      _counteragents = counteragentsSet.toList()..sort();
      _loading = false;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredHistory = _history.where((h) {
        final matchesSearch =
            h['product'].toString().toLowerCase().contains(query) ||
            h['counteragent'].toString().toLowerCase().contains(query);

        final matchesType =
            _selectedOperationType == null ||
            h['operation'] == _selectedOperationType;

        final matchesYear =
            _selectedYear == null ||
            (h['date'] != null &&
                (h['date'] as DateTime).year == _selectedYear);

        final matchesCounteragent =
            _selectedCounteragent == null ||
            h['counteragent'] == _selectedCounteragent;

        return matchesSearch &&
            matchesType &&
            matchesYear &&
            matchesCounteragent;
      }).toList();
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void apply() => _applyFilters();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Фильтры',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Тип операции
                      _chipsFilter<String>(
                        label: 'Тип операции',
                        items: _operationTypes,
                        selected: _selectedOperationType,
                        onSelected: (v) {
                          setModalState(() => _selectedOperationType = v);
                          apply();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Год
                      _chipsFilter<int>(
                        label: 'Год',
                        items: _years,
                        selected: _selectedYear,
                        onSelected: (v) {
                          setModalState(() => _selectedYear = v);
                          apply();
                        },
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Контрагент',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 6),

                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          controller: scrollController,
                          child: ListView(
                            controller: scrollController,
                            children: [
                              _counteragentTile('Все', null, setModalState),
                              ..._counteragents.map(
                                (ca) =>
                                    _counteragentTile(ca, ca, setModalState),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Кнопки Применить и Сбросить
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedOperationType = null;
                                  _selectedYear = null;
                                  _selectedCounteragent = null;
                                });
                                _applyFilters();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Сбросить фильтры',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                apply();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Применить',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _counteragentTile(
    String title,
    String? value,
    StateSetter setModalState,
  ) {
    final isSelected = _selectedCounteragent == value;
    return InkWell(
      onTap: () {
        setModalState(() => _selectedCounteragent = value);
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _chipsFilter<T>({
    required String label,
    required List<T> items,
    required T? selected,
    required void Function(T?) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
                selectedColor: Colors.blue.shade300,
                labelStyle: TextStyle(
                  color: selected == null ? Colors.white : Colors.black,
                  fontWeight: selected == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              ...items.map((item) {
                final isSelected = selected == item;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.toString()),
                    selected: isSelected,
                    selectedColor: Colors.blue.shade300,
                    onSelected: (_) => onSelected(item),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OperationsScreen()),
                );
              },
              icon: const Icon(Icons.auto_graph),
              label: const Text('Новый экран истории (beta)'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по товарам или контрагентам...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredHistory.isEmpty
              ? const Center(child: Text('История операций отсутствует'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredHistory.length,
                  itemBuilder: (_, index) {
                    final h = _filteredHistory[index];
                    return _historyCard(h);
                  },
                ),
        ),
      ],
    );
  }

  Widget _historyCard(Map<String, dynamic> h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h['operation'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Товар: ${h['product'] ?? '-'}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            'Количество: ${h['quantity']}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            'Контрагент: ${h['counteragent']}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            'Дата: ${h['date'] != null ? DateFormat('dd.MM.yyyy').format(h['date']) : '-'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
