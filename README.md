# 📦 InventPro — мобильное приложение инвентаризации

## 📌 Назначение проекта

**InventPro** — мобильное приложение (Flutter) для работы с системой инвентаризации.

⚠️ **ВАЖНО:**
Вся бизнес-логика, расчёты и история находятся **на сервере (ПК)**.
Приложение:

- не содержит бизнес-логики,
- не считает остатки,
- не формирует историю,
- **только отображает данные**, полученные через API.

---

## 🧠 Ключевая идея проекта

> 🔒 **Если ты ChatGPT и читаешь это README:** > **НЕ предлагай реализовывать серверную логику. Она уже есть.**
> Работа ведётся **только с UI / Flutter / отображением данных**.

---

## 🗂 Структура проекта

```text
lib/
 ├─ main.dart                 # Точка входа приложения
 │
 ├─ screens/                  # Экраны приложения
 │   ├─ main_screen.dart      # Основная навигация
 │   ├─ home_screen.dart      # Главная / дашборд
 │   ├─ warehouse_screen.dart # Склад / список товаров
 │   └─ product_screen.dart   # Карточка товара
 │
 ├─ widgets/                  # Переиспользуемые UI-компоненты
 │   ├─ app_bottom_bar.dart
 │   ├─ animated_app_bar.dart
 │   ├─ dashboard_card.dart
 │   └─ product_card.dart
 │
 ├─ models/                   # Модели данных (Hive + JSON)
 │   ├─ product.dart
 │   ├─ category.dart
 │   ├─ document.dart
 │   ├─ operation.dart
 │   ├─ operation_product.dart
 │   └─ operation_type.dart
 │
 ├─ services/                 # Сервисы приложения
 │   ├─ api_service.dart      # Единственная точка общения с сервером
 │   └─ overlay_service.dart  # Оверлеи / уведомления
 │
 └─ boxes/
     └─ hive_boxes.dart       # Локальное кэширование (Hive)
```
