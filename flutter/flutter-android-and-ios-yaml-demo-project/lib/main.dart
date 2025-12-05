
import 'package:flutter/material.dart';

/// =======================
/// MODELS
/// =======================
class Item {
  final String name;
  int quantityRemaining;
  final double unitCost;

  Item({required this.name, required this.quantityRemaining, required this.unitCost});

  double get businessWorth => quantityRemaining * unitCost;
}

class Sale {
  final String itemName;
  final int quantity;
  final double unitPrice; // actual selling price (after discount)
  final DateTime date;

  Sale({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.date,
  });

  double get total => quantity * unitPrice;
}

/// =======================
/// APP STATE (Shared)
/// =======================
class AppState extends ChangeNotifier {
  final List<Item> _items = [];
  final List<Sale> _sales = [];

  List<Item> get items => List.unmodifiable(_items);
  List<Sale> get sales => List.unmodifiable(_sales);

  AppState() {
    // Seed (you can import more from Inventory)
    _items.addAll([
      Item(name: 'Mem card 2gb', quantityRemaining: 2, unitCost: 500),
      Item(name: 'Mem card 4gb', quantityRemaining: 2, unitCost: 600),
      Item(name: 'Mem card 8GB', quantityRemaining: 4, unitCost: 750),
      Item(name: 'Flash Disk 16GB', quantityRemaining: 6, unitCost: 850),
      Item(name: 'Oraimo earphones', quantityRemaining: 11, unitCost: 300),
      Item(name: 'Extension 4 ways', quantityRemaining: 7, unitCost: 400),
    ]);
  }

  String _err = '';
  String get lastError => _err;

  void addItem(String name, int qty, double unitCost) {
    if (name.trim().isEmpty || qty <= 0 || unitCost <= 0) {
      _err = 'Provide valid item name, quantity (>0), and unit cost (>0).';
      notifyListeners();
      return;
    }
    final idx = _items.indexWhere((i) => i.name.toLowerCase() == name.toLowerCase());
    if (idx >= 0) {
      _items[idx].quantityRemaining += qty;
    } else {
      _items.add(Item(name: name.trim(), quantityRemaining: qty, unitCost: unitCost));
    }
    _err = '';
    notifyListeners();
  }

  bool recordSale({
    required String itemName,
    required int qty,
    DateTime? date,
    double? unitPriceOverride,
  }) {
    final item = _items.firstWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
      orElse: () => Item(name: '', quantityRemaining: 0, unitCost: 0),
    );
    if (item.name.isEmpty) {
      _err = 'Item "$itemName" not found.';
      notifyListeners();
      return false;
    }
    if (qty <= 0) {
      _err = 'Quantity must be > 0.';
      notifyListeners();
      return false;
    }
    if (item.quantityRemaining < qty) {
      _err = 'Insufficient stock. Available: ${item.quantityRemaining}.';
      notifyListeners();
      return false;
    }
    final priceToUse = (unitPriceOverride != null && unitPriceOverride > 0)
        ? unitPriceOverride
        : item.unitCost;

    item.quantityRemaining -= qty;
    _sales.add(Sale(
      itemName: item.name,
      quantity: qty,
      unitPrice: priceToUse,
      date: date ?? DateTime.now(),
    ));
    _err = '';
    notifyListeners();
    return true;
  }

  // Analytics helpers
  DateTime _dOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Sale> salesOn(DateTime date) =>
      _sales.where((s) => _dOnly(s.date) == _dOnly(date)).toList();

  List<Sale> salesBetween(DateTime start, DateTime end) {
    final s = _dOnly(start), e = _dOnly(end);
    return _sales.where((x) {
      final d = _dOnly(x.date);
      return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
          (d.isAtSameMomentAs(e) || d.isBefore(e));
    }).toList();
  }

  double revenueBetween(DateTime start, DateTime end) =>
      salesBetween(start, end).fold(0.0, (sum, s) => sum + s.total);

  int transactionsBetween(DateTime start, DateTime end) =>
      salesBetween(start, end).length;

  int distinctItemsSoldBetween(DateTime start, DateTime end) =>
      salesBetween(start, end).map((s) => s.itemName).toSet().length;

  List<MapEntry<String, int>> topByQtyBetween({
    required DateTime start,
    required DateTime end,
    int top = 5,
  }) {
    final map = <String, int>{};
    for (final s in salesBetween(start, end)) {
      map[s.itemName] = (map[s.itemName] ?? 0) + s.quantity;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(top).toList();
  }

  List<MapEntry<String, double>> topByRevenueBetween({
    required DateTime start,
    required DateTime end,
    int top = 5,
  }) {
    final map = <String, double>{};
    for (final s in salesBetween(start, end)) {
      map[s.itemName] = (map[s.itemName] ?? 0.0) + s.total;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(top).toList();
  }
}

/// =======================
/// STATE PROVIDER
/// =======================
class AppStateProvider extends InheritedNotifier<AppState> {
  final AppState appState;
  const AppStateProvider({super.key, required this.appState, required Widget child})
      : super(notifier: appState, child: child);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!.appState;

  @override
  bool updateShouldNotify(AppStateProvider oldWidget) => oldWidget.appState != appState;
}

/// =======================
/// ENTRY
/// =======================
void main() => runApp(const CulinkApp());

class CulinkApp extends StatefulWidget {
  const CulinkApp({super.key});
  @override
  State<CulinkApp> createState() => _CulinkAppState();
}

class _CulinkAppState extends State<CulinkApp> {
  final AppState _state = AppState();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      appState: _state,
      child: MaterialApp(
        title: 'Culink Shop',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Culink Shop')),
          body: IndexedStack(
            index: _tab,
            children: const [
              InventoryScreen(),
              SalesScreen(),      // fixed
              DashboardScreen(),  // fixed
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
              NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Sales'),
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// INVENTORY (search + import)
/// =======================
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final items = state.items;
    final filtered = _q.isEmpty ? items : items.where((i) => i.name.toLowerCase().contains(_q)).toList();

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search inventory items...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () { _searchCtrl.clear(); }, icon: const Icon(Icons.clear)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(it.name),
                      subtitle: Text('Unit: Ksh ${it.unitCost.toStringAsFixed(0)}   Stock: ${it.quantityRemaining}   Worth: Ksh ${it.businessWorth.toStringAsFixed(0)}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'fab_import',
                onPressed: () => _showImportDialog(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'fab_add',
                onPressed: () => _showAddItemDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        if (state.lastError.isNotEmpty)
          Positioned(left: 16, bottom: 100, right: 16, child: _ErrorBanner(message: state.lastError)),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final state = AppStateProvider.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item name')),
              TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Unit cost (Ksh)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? -1;
              final cost = double.tryParse(costCtrl.text.trim()) ?? -1;
              state.addItem(name, qty, cost);
              if (state.lastError.isEmpty) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final state = AppStateProvider.of(context);
    final pasteCtrl = TextEditingController();
    bool firstRowHeader = true;
    List<_ParsedLine> preview = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          void doPreview() {
            preview = _parsePastedText(pasteCtrl.text, firstRowHeader: firstRowHeader);
            setState(() {});
          }
          final okCount = preview.where((p) => p.error == null).length;

          return AlertDialog(
            title: const Text('Import Items from Paste'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paste rows with 3 columns: Item, Quantity, Unit Cost. Supports comma/semicolon/tab.'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pasteCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Paste here',
                        border: OutlineInputBorder(),
                        hintText: 'Example:\nMem card 8GB\t4\t750',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(value: firstRowHeader, onChanged: (v) { firstRowHeader = v ?? true; doPreview(); }),
                        const Text('First row is header'),
                        const Spacer(),
                        OutlinedButton.icon(onPressed: doPreview, icon: const Icon(Icons.visibility), label: const Text('Preview')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (preview.isNotEmpty) ...[
                      Text('Preview (${okCount} valid / ${preview.length} total):', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: preview.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final p = preview[i];
                          if (p.error != null) {
                            return Card(
                              color: Colors.red.shade50,
                              child: ListTile(
                                leading: Icon(Icons.error_outline, color: Colors.red.shade700),
                                title: Text(p.rawLine),
                                subtitle: Text(p.error!, style: TextStyle(color: Colors.red.shade700)),
                              ),
                            );
                          }
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text(p.name ?? ''),
                              subtitle: Text('Qty: ${p.qty}   Unit: Ksh ${p.unitCost?.toStringAsFixed(0)}'),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              FilledButton.icon(
                onPressed: okCount > 0 ? () {
                  for (final p in preview.where((x) => x.error == null)) {
                    state.addItem(p.name!, p.qty!, p.unitCost!);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $okCount item(s).')));
                } : null,
                icon: const Icon(Icons.upload),
                label: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// =======================
/// SALES (stable search + discount price)
/// =======================
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Item? selectedItem;

  @override
  void dispose() {
    _searchCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  double _currentTotal() {
    final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final p = double.tryParse(priceCtrl.text.trim()) ?? (selectedItem?.unitCost ?? 0);
    return q * p;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final items = state.items;

    final q = _searchCtrl.text.trim().toLowerCase();
    final suggestions = q.isEmpty
        ? <Item>[]
        : items.where((i) => i.name.toLowerCase().contains(q)).toList();

    final todaysSales = state.salesOn(selectedDate);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record a Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Search box with inline suggestions list (no overlay -> no white screen)
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search item',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (suggestions.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (_, i) {
                        final it = suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(it.name),
                          subtitle: Text('Available: ${it.quantityRemaining} • Guiding: Ksh ${it.unitCost.toStringAsFixed(0)}'),
                          onTap: () {
                            setState(() {
                              selectedItem = it;
                              _searchCtrl.text = it.name;
                              priceCtrl.text = it.unitCost.toStringAsFixed(0); // prefill guiding price
                            });
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),
                if (selectedItem != null)
                  Text(
                    'Selected: ${selectedItem!.name}   Guiding: Ksh ${selectedItem!.unitCost.toStringAsFixed(0)}   Available: ${selectedItem!.quantityRemaining}',
                    style: const TextStyle(color: Colors.teal),
                  ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(labelText: 'Selling Price (Ksh)', border: OutlineInputBorder(), hintText: 'Override allowed'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Sale date: ${_fmtDate(selectedDate)}', style: const TextStyle(fontWeight: FontWeight.w500))),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Total: Ksh ${_currentTotal().toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        if (selectedItem == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an item from suggestions.')));
                          return;
                        }
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? -1;
                        final price = double.tryParse(priceCtrl.text.trim()) ?? -1;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity (> 0).')));
                          return;
                        }
                        if (price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid selling price (> 0).')));
                          return;
                        }
                        final ok = AppStateProvider.of(context).recordSale(
                          itemName: selectedItem!.name,
                          qty: qty,
                          date: selectedDate,
                          unitPriceOverride: price,
                        );
                        if (ok) {
                          qtyCtrl.text = '1';
                          priceCtrl.text = selectedItem!.unitCost.toStringAsFixed(0);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recorded: ${selectedItem!.name} x$qty @ Ksh ${price.toStringAsFixed(0)}')));
                          setState(() {});
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStateProvider.of(context).lastError)));
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Record Sale'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Sales list for selected date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Expanded(child: Text('Sales on ${_fmtDate(selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
                },
                icon: const Icon(Icons.filter_alt),
                label: const Text('Filter date'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: todaysSales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = todaysSales[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('${s.itemName}  x${s.quantity}'),
                  subtitle: Text('Price: Ksh ${s.unitPrice.toStringAsFixed(0)}   Total: Ksh ${s.total.toStringAsFixed(0)}   Date: ${_fmtDate(s.date)}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// =======================
/// DASHBOARD (date filters)
/// =======================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime start = DateTime.now(), end = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    start = DateTime(now.year, now.month, now.day);
    end   = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    final total = state.revenueBetween(start, end);
    final txs = state.transactionsBetween(start, end);
    final distinctItems = state.distinctItemsSoldBetween(start, end);
    final topQty = state.topByQtyBetween(start: start, end: end, top: 5);
    final topRev = state.topByRevenueBetween(start: start, end: end, top: 5);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text('Filter Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _DateField(label: 'From', date: start, onPick: (d) => setState(() => start = d))),
                    const SizedBox(width: 8),
                    Expanded(child: _DateField(label: 'To',   date: end,   onPick: (d) => setState(() => end = d))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('Today'), onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        start = DateTime(now.year, now.month, now.day);
                        end   = DateTime(now.year, now.month, now.day);
                      });
                    }),
                    ActionChip(label: const Text('Last 7 days'), onPressed: () {
                      final now = DateTime.now();
                      final seven = now.subtract(const Duration(days: 6));
                      setState(() {
                        start = DateTime(seven.year, seven.month, seven.day);
                        end   = DateTime(now.year, now.month, now.day);
                      });
                    }),
                    ActionChip(label: const Text('This month'), onPressed: () {
                      final now = DateTime.now();
                      final first = DateTime(now.year, now.month, 1);
                      setState(() {
                        start = first;
                        end   = DateTime(now.year, now.month, now.day);
                      });
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.attach_money),
            title: Text('Total Sales (${_fmtRange(start, end)})'),
            subtitle: Text('Ksh ${total.toStringAsFixed(0)}'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Transactions'), subtitle: Text('$txs')))),
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Distinct items sold'), subtitle: Text('$distinctItems')))),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top‑Selling by Quantity (${_fmtRange(start, end)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (topQty.isEmpty) const Text('No sales in selected range.'),
                for (final e in topQty) ListTile(leading: const Icon(Icons.trending_up), title: Text(e.key), trailing: Text('Qty: ${e.value}')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top‑Selling by Revenue (${_fmtRange(start, end)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (topRev.isEmpty) const Text('No sales in selected range.'),
                for (final e in topRev) ListTile(leading: const Icon(Icons.leaderboard), title: Text(e.key), trailing: Text('Ksh ${e.value.toStringAsFixed(0)}')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtRange(DateTime s, DateTime e) => (s.year == e.year && s.month == e.month && s.day == e.day) ? _fmtDate(s) : '${_fmtDate(s)} → ${_fmtDate(e)}';
}

/// =======================
/// Small widgets / helpers
/// =======================
class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onPick;
  const _DateField({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text('$label: ${_fmtDate(date)}'),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(DateTime(picked.year, picked.month, picked.day));
      },
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700))),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// PASTE PARSER (Import)
/// =======================
class _ParsedLine {
  final String rawLine;
  final String? name;
  final int? qty;
  final double? unitCost;
  final String? error;
  _ParsedLine.success(this.rawLine, this.name, this.qty, this.unitCost) : error = null;
  _ParsedLine.error(this.rawLine, this.error) : name = null, qty = null, unitCost = null;
}

List<_ParsedLine> _parsePastedText(String text, {bool firstRowHeader = true}) {
  final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  final parsed = <_ParsedLine>[];
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i == 0 && firstRowHeader) continue;
    final parts = line.split(RegExp(r'[,\t;]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length < 3) {
      parsed.add(_ParsedLine.error(line, 'Expected 3 columns (name, quantity, unit cost). Found ${parts.length}.'));
      continue;
    }
    List<String> cols = parts;
    if (int.tryParse(parts[0]) != null && parts.length >= 4) cols = parts.sublist(1);
    final name = cols[0];
    final qtyStr = cols.length >= 2 ? cols[1] : '';
    final costStr = cols.length >= 3 ? cols[2] : '';
    final qty = _toInt(qtyStr);
    final cost = _toDouble(costStr);
    if (name.isEmpty) { parsed.add(_ParsedLine.error(line, 'Item name is empty.')); continue; }
    if (qty == null || qty <= 0) { parsed.add(_ParsedLine.error(line, 'Quantity must be a positive integer.')); continue; }
    if (cost == null || cost <= 0) { parsed.add(_ParsedLine.error(line, 'Unit cost must be a positive number.')); continue; }
    parsed.add(_ParsedLine.success(line, name, qty, cost));
  }
  return parsed;
}

int? _toInt(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9\-]'), ''));
double? _toDouble(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9\.\-]'), ''));
