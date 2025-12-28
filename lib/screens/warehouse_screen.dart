import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/product.dart';
import '../models/category.dart';
import '../widgets/product_card.dart';
import '../theme/colors.dart';
import 'product_screen.dart';
import '../boxes/hive_boxes.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Box<Product> _productBox;
  late Box<Category> _categoryBox;

  List<Product> _filteredProducts = [];
  List<Category> _categories = [];

  int? _selectedCategoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _initHive() async {
    _productBox = await Hive.openBox<Product>(HiveBoxes.products);
    _categoryBox = await Hive.openBox<Category>(HiveBoxes.categories);

    _loadLocalData();
  }

  void _loadLocalData() {
    _categories = _categoryBox.values.toList();
    _filteredProducts = _productBox.values.toList();

    setState(() => _loading = false);
  }

  // -------------------------------
  // 🔹 ГЛАВНАЯ ЛОГИКА ФИЛЬТРАЦИИ
  // -------------------------------
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = _productBox.values.where((product) {
        final matchesSearch =
            product.name.toLowerCase().contains(query) ||
            product.invNumber.toLowerCase().contains(query);

        final matchesCategory =
            _selectedCategoryId == null ||
            _isCategoryMatch(product.categoryId, _selectedCategoryId!);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  /// ✅ Проверка: принадлежит ли категория товару
  /// или любой из её родительских
  bool _isCategoryMatch(int productCategoryId, int selectedCategoryId) {
    int? currentId = productCategoryId;

    while (currentId != null && currentId != 0) {
      if (currentId == selectedCategoryId) {
        return true;
      }
      currentId = _categoryBox.get(currentId)?.parentId;
    }
    return false;
  }

  void _selectCategory(int? id) {
    _selectedCategoryId = id;
    _applyFilters();
    Navigator.of(context).pop();
  }

  // -------------------------------
  // 🔹 ДЕРЕВО КАТЕГОРИЙ
  // -------------------------------
  Widget _buildCategoryTree(int? parentId) {
    final children = _categories.where((c) => c.parentId == parentId).toList();

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      children: children.map((category) {
        return ExpansionTile(
          key: ValueKey(category.id),
          title: Text(
            category.name,
            style: TextStyle(
              color: _selectedCategoryId == category.id
                  ? AppColors.brand
                  : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            _buildCategoryTree(category.id),
            ListTile(
              title: const Text('Выбрать эту категорию'),
              onTap: () => _selectCategory(category.id),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: _buildCategoryTree(null)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------
  // 🔹 UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по товарам...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showCategoryFilter,
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
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredProducts.length,
              itemBuilder: (_, i) {
                final product = _filteredProducts[i];
                final categoryName =
                    _categoryBox.get(product.categoryId)?.name ?? '-';

                return ProductCard(
                  title: product.name,
                  inventoryNumber: product.invNumber,
                  price: product.price,
                  quantity: product.quantity,
                  total: product.sum,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductScreen(
                          title: product.name,
                          inventoryNumber: product.invNumber,
                          price: product.price,
                          quantity: product.quantity,
                          total: product.sum,
                          categoryPath: categoryName,
                          images: const [],
                          history: const [],
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
