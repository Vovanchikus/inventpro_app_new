import 'package:flutter/material.dart';
import '../widgets/product_card.dart';
import '../theme/colors.dart';
import 'product_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  WarehouseScreenState createState() => WarehouseScreenState();
}

class WarehouseScreenState extends State<WarehouseScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, dynamic>> _products;
  late List<Map<String, dynamic>> _filteredProducts;

  // Категории с вложенностью
  late List<Map<String, dynamic>> _categories;

  // Выбранная категория
  String? _selectedCategoryPath;

  // Раскрытые категории
  Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();

    // Продукты с categoryPath
    _products = List.generate(450, (index) {
      double price = (50 + index % 100).toDouble();
      double quantity = (1 + index % 20).toDouble();
      double total = price * quantity;

      // Простая имитация категории
      String categoryPath;
      if (index % 2 == 0) {
        categoryPath = 'Категория 1/Подкатегория 1-1';
      } else if (index % 3 == 0) {
        categoryPath = 'Категория 1/Подкатегория 1-2';
      } else {
        categoryPath = 'Категория 2';
      }

      return {
        'title': 'Товар ${index + 1}',
        'inventory': 'INV-${1000 + index}',
        'price': price,
        'quantity': quantity,
        'total': total,
        'categoryPath': categoryPath,
      };
    });

    _filteredProducts = List.from(_products);

    _searchController.addListener(_onSearchChanged);

    // Пример категорий с вложенностью
    _categories = [
      {
        'name': 'Категория 1',
        'children': [
          {
            'name': 'Подкатегория 1-1',
            'children': [
              {'name': 'Подподкатегория 1-1-1', 'children': []},
              {'name': 'Подподкатегория 1-1-2', 'children': []},
            ],
          },
          {'name': 'Подкатегория 1-2', 'children': []},
        ],
      },
      {'name': 'Категория 2', 'children': []},
    ];
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        final title = (p['title'] as String).toLowerCase();
        final inventory = (p['inventory'] as String).toLowerCase();
        final matchesSearch =
            title.contains(query) || inventory.contains(query);

        final matchesCategory =
            _selectedCategoryPath == null ||
            (p['categoryPath'] as String).startsWith(_selectedCategoryPath!);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _expandParentCategories(String path) {
    List<String> parts = path.split('/');
    String current = '';
    for (var part in parts) {
      current = current.isEmpty ? part : '$current/$part';
      _expandedCategories[current] = true;
    }
  }

  /// Открыть нижнюю панель фильтров
  void showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: _buildCategoryList(_categories)),
        );
      },
    );
  }

  Widget _buildCategoryList(
    List<Map<String, dynamic>> categories, [
    String parentPath = '',
    int level = 0,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((cat) {
        String fullPath = parentPath.isEmpty
            ? cat['name']
            : '$parentPath/${cat['name']}';
        bool hasChildren = (cat['children'] as List).isNotEmpty;

        // Подтекст (можно менять на что угодно, например количество товаров)
        String subtitle = cat['subtitle'] ?? 'Описание категории';

        return ExpansionTile(
          key: PageStorageKey(fullPath),
          initiallyExpanded: _expandedCategories[fullPath] ?? false,
          title: Padding(
            padding: EdgeInsets.only(left: level * 8.0),
            child: Text(
              cat['name'],
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _selectedCategoryPath == fullPath
                    ? AppColors.brand
                    : Colors.black,
              ),
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(left: level * 8.0),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // Если нет подкатегорий, стрелка не показывается
          trailing: hasChildren ? null : const SizedBox.shrink(),
          children: hasChildren
              ? (cat['children'] as List)
                    .map<Widget>(
                      (child) =>
                          _buildCategoryList([child], fullPath, level + 1),
                    )
                    .toList()
              : [],
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedCategories[fullPath] = expanded;
              if (!hasChildren && expanded) {
                _selectedCategoryPath = fullPath;
                _expandParentCategories(fullPath);
                _applyFilters();
                Navigator.of(context).pop(); // закрываем bottom sheet
              }
            });
          },
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по товарам...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: showFilterBottomSheet,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ),

          // Список товаров
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final p = _filteredProducts[index];
                return ProductCard(
                  title: p['title'] as String,
                  inventoryNumber: p['inventory'] as String,
                  price: p['price'] as double,
                  quantity: p['quantity'] as double,
                  total: p['total'] as double,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductScreen(
                          title: p['title'] as String,
                          inventoryNumber: p['inventory'] as String,
                          price: p['price'] as double,
                          quantity: p['quantity'] as double,
                          total: p['total'] as double,
                          categoryPath: p['categoryPath'] as String,
                          images: [
                            'https://codestore.my1.ru/izobrazhenie_whatsapp_2025-10-22_v_11.22.22_acc9fa.jpg',
                            'https://codestore.my1.ru/izobrazhenie_whatsapp_2025-10-22_v_11.22.22_182a2d.jpg',
                            'https://codestore.my1.ru/izobrazhenie_whatsapp_2025-10-22_v_11.22.22_da5ee5.jpg',
                          ],
                          history: [
                            {
                              'title': 'Поступление на склад',
                              'date': '28.12.2025',
                              'description': 'Товар принят в количестве 10 шт.',
                            },
                            {
                              'title': 'Продажа',
                              'date': '30.12.2025',
                              'description': 'Продано 2 шт.',
                            },
                            {
                              'title': 'Продажа',
                              'date': '30.12.2025',
                              'description': 'Продано 2 шт.',
                            },
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
