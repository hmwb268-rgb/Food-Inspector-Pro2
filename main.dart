import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const FoodInspectorApp());
}

const modules = <String, ModuleConfig>{
  'facilities': ModuleConfig('المنشآت الغذائية', Icons.storefront, [
    FieldConfig('name', 'اسم المنشأة', required: true),
    FieldConfig('activity', 'نوع النشاط', options: ['مطعم', 'بقالة / سوبر ماركت', 'مخبز', 'جزارة', 'دواجن', 'مصنع أغذية', 'مخزن أغذية', 'ألبان', 'أخرى']),
    FieldConfig('owner', 'اسم المالك / المسؤول'),
    FieldConfig('phone', 'رقم الهاتف'), FieldConfig('governorate', 'المحافظة'),
    FieldConfig('district', 'المركز / المدينة'), FieldConfig('address', 'العنوان التفصيلي', required: true),
    FieldConfig('status', 'الحالة', options: ['قائمة', 'تحتاج متابعة', 'مغلقة مؤقتًا', 'غير محددة']),
    FieldConfig('notes', 'ملاحظات', multiline: true),
  ]),
  'visits': ModuleConfig('الزيارات التفتيشية', Icons.fact_check, [
    FieldConfig('facility', 'اسم المنشأة', required: true), FieldConfig('date', 'تاريخ الزيارة', date: true, required: true),
    FieldConfig('kind', 'نوع الزيارة', options: ['دورية', 'متابعة', 'شكوى', 'إعادة تفتيش', 'أخرى']),
    FieldConfig('cleanliness', 'النظافة العامة', options: ['مطابق', 'غير مطابق', 'لم يُقيّم']),
    FieldConfig('handling', 'تداول الأغذية', options: ['مطابق', 'غير مطابق', 'لم يُقيّم']),
    FieldConfig('storage', 'التخزين والتبريد', options: ['مطابق', 'غير مطابق', 'لم يُقيّم']),
    FieldConfig('temperature', 'درجة الحرارة / الوحدة'),
    FieldConfig('expiry', 'صلاحية الأغذية', options: ['مطابق', 'غير مطابق', 'لم يُقيّم']),
    FieldConfig('workers', 'الشهادات الصحية للعاملين', options: ['مطابق', 'غير مطابق', 'لا ينطبق', 'لم يُقيّم']),
    FieldConfig('pests', 'مكافحة الآفات', options: ['مطابق', 'غير مطابق', 'لم يُقيّم']),
    FieldConfig('observations', 'الملاحظات', multiline: true), FieldConfig('actions', 'الإجراءات المتخذة', multiline: true),
    FieldConfig('followDate', 'موعد إعادة التفتيش', date: true), FieldConfig('status', 'الحالة', options: ['مسودة', 'مكتملة', 'تحتاج متابعة']),
  ]),
  'violations': ModuleConfig('المخالفات', Icons.report_problem, [
    FieldConfig('facility', 'اسم المنشأة', required: true), FieldConfig('date', 'تاريخ اكتشافها', date: true, required: true),
    FieldConfig('description', 'وصف المخالفة', multiline: true, required: true),
    FieldConfig('category', 'التصنيف', options: ['نظافة', 'تخزين', 'صلاحية أغذية', 'تداول أغذية', 'شهادات صحية', 'أخرى']),
    FieldConfig('severity', 'درجة الخطورة - تقدير مبدئي', options: ['تحتاج تقييم', 'منخفضة', 'متوسطة', 'مرتفعة']),
    FieldConfig('action', 'الإجراء المتخذ'), FieldConfig('reportNo', 'رقم المحضر إن وجد'),
    FieldConfig('status', 'حالة المتابعة', options: ['جديدة', 'قيد المتابعة', 'تمت الإحالة', 'أغلقت']),
  ]),
  'samples': ModuleConfig('العينات والتحاليل', Icons.science, [
    FieldConfig('facility', 'اسم المنشأة', required: true), FieldConfig('date', 'تاريخ السحب', date: true, required: true),
    FieldConfig('kind', 'نوع العينة', required: true), FieldConfig('product', 'اسم المنتج'), FieldConfig('manufacturer', 'الشركة المصنعة'),
    FieldConfig('batch', 'رقم التشغيلة'), FieldConfig('expiry', 'تاريخ الصلاحية', date: true),
    FieldConfig('reason', 'سبب السحب'), FieldConfig('lab', 'المعمل المستلم'), FieldConfig('sentDate', 'تاريخ الإرسال', date: true),
    FieldConfig('resultDate', 'تاريخ ظهور النتيجة', date: true), FieldConfig('result', 'نتيجة التحليل حسب التقرير', multiline: true),
    FieldConfig('status', 'حالة العينة', options: ['تم تسجيلها', 'تم سحبها', 'تم إرسالها للمعمل', 'قيد التحليل', 'ظهرت النتيجة', 'تحتاج إلى إجراء', 'أغلقت المتابعة']),
  ]),
  'tasks': ModuleConfig('المواعيد والمتابعة', Icons.event_note, [
    FieldConfig('title', 'عنوان المهمة / المنشأة', required: true), FieldConfig('date', 'التاريخ', date: true, required: true),
    FieldConfig('reason', 'سبب الزيارة أو المتابعة'), FieldConfig('priority', 'الأولوية', options: ['عادية', 'مهمة', 'عاجلة']),
    FieldConfig('address', 'العنوان'), FieldConfig('status', 'الحالة', options: ['مجدولة', 'تمت', 'مؤجلة']), FieldConfig('notes', 'ملاحظات', multiline: true),
  ]),
};

class FieldConfig {
  final String key, label;
  final bool required, multiline, date;
  final List<String>? options;
  const FieldConfig(this.key, this.label, {this.required = false, this.multiline = false, this.date = false, this.options});
}
class ModuleConfig {
  final String title; final IconData icon; final List<FieldConfig> fields;
  const ModuleConfig(this.title, this.icon, this.fields);
}

class AppDb {
  AppDb._(); static final instance = AppDb._(); Database? _db;
  Future<void> init() async {
    final base = await getDatabasesPath();
    _db = await openDatabase(p.join(base, 'food_inspector_pro.db'), version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE records (id INTEGER PRIMARY KEY AUTOINCREMENT, module TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
      });
  }
  Database get db => _db!;
  Future<List<Map<String, dynamic>>> list(String module) async => db.query('records', where: 'module = ?', whereArgs: [module], orderBy: 'updated_at DESC');
  Future<int> count(String module) async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM records WHERE module = ?', [module])) ?? 0;
  Future<void> save(String module, Map<String, dynamic> payload, {int? id}) async {
    final now = DateTime.now().toIso8601String();
    if (id == null) { await db.insert('records', {'module': module, 'payload': jsonEncode(payload), 'created_at': now, 'updated_at': now}); }
    else { await db.update('records', {'payload': jsonEncode(payload), 'updated_at': now}, where: 'id = ? AND module = ?', whereArgs: [id, module]); }
  }
  Future<void> delete(int id) => db.delete('records', where: 'id = ?', whereArgs: [id]);
  Future<Map<String, dynamic>> exportData() async {
    final rows = await db.query('records', orderBy: 'id ASC');
    return {'app': 'Food Inspector Pro', 'schemaVersion': 1, 'exportedAt': DateTime.now().toIso8601String(), 'records': rows};
  }
  Future<void> restore(Map<String, dynamic> data) async {
    if (data['app'] != 'Food Inspector Pro' || data['records'] is! List) throw const FormatException('نسخة احتياطية غير صحيحة');
    final rows = (data['records'] as List).cast<Map>();
    await db.transaction((txn) async {
      await txn.delete('records');
      for (final raw in rows) {
        final r = Map<String, dynamic>.from(raw);
        final module = r['module']?.toString();
        if (!modules.containsKey(module)) continue;
        await txn.insert('records', {'module': module, 'payload': r['payload']?.toString() ?? '{}', 'created_at': r['created_at']?.toString() ?? DateTime.now().toIso8601String(), 'updated_at': r['updated_at']?.toString() ?? DateTime.now().toIso8601String()});
      }
    });
  }
}

class FoodInspectorApp extends StatelessWidget {
  const FoodInspectorApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: 'Food Inspector Pro', debugShowCheckedModeBanner: false, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087e8b)), useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff4f7f8)), home: const HomePage());
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  String current = 'home'; int refresh = 0;
  void reload() => setState(() => refresh++);
  @override Widget build(BuildContext context) {
    final entries = <String, ModuleConfig>{'home': const ModuleConfig('لوحة التحكم', Icons.dashboard, []), ...modules};
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text(current == 'home' ? 'مفتش الأغذية الذكي' : entries[current]!.title), actions: [IconButton(tooltip: 'نسخ احتياطي', icon: const Icon(Icons.backup_outlined), onPressed: exportBackup)]),
      drawer: Drawer(child: SafeArea(child: Column(children: [const ListTile(leading: CircleAvatar(child: Icon(Icons.shield_outlined)), title: Text('Food Inspector Pro', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('نسخة أولية تعمل دون إنترنت')), const Divider(), Expanded(child: ListView(children: [ListTile(leading: const Icon(Icons.dashboard), title: const Text('الرئيسية'), selected: current == 'home', onTap: () => navigate('home')), ...modules.entries.map((e) => ListTile(leading: Icon(e.value.icon), title: Text(e.value.title), selected: current == e.key, onTap: () => navigate(e.key))), const Divider(), ListTile(leading: const Icon(Icons.backup), title: const Text('نسخ احتياطي / استعادة'), onTap: () { Navigator.pop(context); backupMenu(); })]))]))),
      body: current == 'home' ? dashboard() : RecordListPage(key: ValueKey('$current-$refresh'), module: current, onChanged: reload),
      floatingActionButton: current == 'home' ? null : FloatingActionButton.extended(onPressed: () => editRecord(current), icon: const Icon(Icons.add), label: const Text('إضافة سجل')),
    ));
  }
  void navigate(String page) { Navigator.pop(context); setState(() => current = page); }
  Widget dashboard() => FutureBuilder<List<int>>(future: Future.wait(modules.keys.map((k) => AppDb.instance.count(k))), builder: (context, snap) {
    final counts = snap.data ?? List.filled(modules.length, 0); final keys = modules.keys.toList();
    return ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xff087e8b), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('سجّل جولتك بثقة', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('البيانات محفوظة محليًا على الجهاز. يمكنك تصدير نسخة احتياطية واستعادتها لاحقًا.', style: TextStyle(color: Colors.white, height: 1.5))])), const SizedBox(height: 16), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: keys.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.25, crossAxisSpacing: 12, mainAxisSpacing: 12), itemBuilder: (context, i) { final cfg = modules[keys[i]]!; return InkWell(onTap: () => setState(() => current = keys[i]), child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(cfg.icon, size: 28, color: const Color(0xff087e8b)), Text(cfg.title, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${counts[i]} سجل', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])))); }), const SizedBox(height: 14), const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('مهم: هذه أداة تنظيم وتوثيق ميداني وليست نموذجًا قانونيًا رسميًا معتمدًا. راجع الإجراءات والنماذج المعتمدة لدى جهة عملك.', style: TextStyle(height: 1.5))))]);
  });
  Future<void> editRecord(String module, {Map<String, dynamic>? record, int? id}) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => RecordFormDialog(config: modules[module]!, initial: record ?? {}));
    if (result != null) { await AppDb.instance.save(module, result, id: id); reload(); }
  }
  Future<void> exportBackup() async {
    try { final data = await AppDb.instance.exportData(); final dir = await getApplicationDocumentsDirectory(); final file = File(p.join(dir.path, 'FoodInspectorPro_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json')); await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data)); await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من Food Inspector Pro'); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء النسخة: $e'))); }
  }
  Future<void> restoreBackup() async {
    try { final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true); if (picked == null) return; final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes(); final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>; if (!mounted) return; final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('استعادة نسخة احتياطية'), content: const Text('سيتم استبدال السجلات الحالية بمحتوى النسخة المختارة. هل تريد المتابعة؟'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة'))])); if (ok != true) return; await AppDb.instance.restore(decoded); reload(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة بنجاح'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر استعادة النسخة: $e'))); }
  }
  Future<void> backupMenu() async { await showModalBottomSheet<void>(context: context, builder: (c) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.upload_file), title: const Text('إنشاء نسخة احتياطية ومشاركتها'), onTap: () { Navigator.pop(c); exportBackup(); }), ListTile(leading: const Icon(Icons.restore), title: const Text('استعادة نسخة JSON'), onTap: () { Navigator.pop(c); restoreBackup(); })]))); }
}

class RecordListPage extends StatefulWidget { final String module; final VoidCallback onChanged; const RecordListPage({super.key, required this.module, required this.onChanged}); @override State<RecordListPage> createState() => _RecordListPageState(); }
class _RecordListPageState extends State<RecordListPage> {
  String query = '';
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: AppDb.instance.list(widget.module), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snap.data!.where((r) { final data = jsonDecode(r['payload'] as String) as Map<String, dynamic>; return jsonEncode(data).toLowerCase().contains(query.toLowerCase()); }).toList();
    return Column(children: [Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث في السجلات...', border: OutlineInputBorder()), onChanged: (v) => setState(() => query = v))), Expanded(child: rows.isEmpty ? const Center(child: Text('لا توجد سجلات بعد. اضغط «إضافة سجل» للبدء.')) : ListView.builder(itemCount: rows.length, itemBuilder: (context, i) { final row = rows[i]; final data = jsonDecode(row['payload'] as String) as Map<String, dynamic>; final title = (data['name'] ?? data['title'] ?? data['facility'] ?? data['product'] ?? data['kind'] ?? data['description'] ?? 'سجل بدون عنوان').toString(); final sub = [data['date'], data['status'], data['activity']].where((v) => v != null && v.toString().isNotEmpty).join(' • '); return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: sub.isEmpty ? null : Text(sub), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') { final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => RecordFormDialog(config: modules[widget.module]!, initial: data)); if (result != null) { await AppDb.instance.save(widget.module, result, id: row['id'] as int); widget.onChanged(); setState(() {}); } } else if (v == 'delete') { final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('حذف السجل؟'), content: const Text('لا يمكن التراجع عن هذا الإجراء.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف'))])); if (ok == true) { await AppDb.instance.delete(row['id'] as int); widget.onChanged(); setState(() {}); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]), onTap: () async { final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => RecordFormDialog(config: modules[widget.module]!, initial: data)); if (result != null) { await AppDb.instance.save(widget.module, result, id: row['id'] as int); widget.onChanged(); setState(() {}); } })); }))]);
  });
}

class RecordFormDialog extends StatefulWidget { final ModuleConfig config; final Map<String, dynamic> initial; const RecordFormDialog({super.key, required this.config, required this.initial}); @override State<RecordFormDialog> createState() => _RecordFormDialogState(); }
class _RecordFormDialogState extends State<RecordFormDialog> {
  final formKey = GlobalKey<FormState>(); late final Map<String, TextEditingController> controllers; late final Map<String, String?> selections;
  @override void initState() { super.initState(); controllers = {for (final f in widget.config.fields.where((f) => f.options == null)) f.key: TextEditingController(text: widget.initial[f.key]?.toString() ?? (f.date && f.key == 'date' && widget.initial[f.key] == null ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : ''))}; selections = {for (final f in widget.config.fields.where((f) => f.options != null)) f.key: f.options!.contains(widget.initial[f.key]) ? widget.initial[f.key] as String : null}; }
  @override void dispose() { for (final c in controllers.values) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: Text(widget.initial.isEmpty ? 'إضافة ${widget.config.title}' : 'تعديل ${widget.config.title}'), content: SizedBox(width: 500, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: widget.config.fields.map((f) { if (f.options != null) return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: selections[f.key], decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()), items: f.options!.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (v) => selections[f.key] = v, validator: (v) => f.required && (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null)); return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controllers[f.key], readOnly: f.date, onTap: f.date ? () async { final currentDate = DateTime.tryParse(controllers[f.key]!.text) ?? DateTime.now(); final picked = await showDatePicker(context: context, initialDate: currentDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) controllers[f.key]!.text = DateFormat('yyyy-MM-dd').format(picked); } : null, maxLines: f.multiline ? 3 : 1, decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder(), suffixIcon: f.date ? const Icon(Icons.calendar_month) : null), validator: (v) => f.required && (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null)); }).toList()))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton.icon(onPressed: () { if (!formKey.currentState!.validate()) return; final result = <String, dynamic>{}; for (final f in widget.config.fields) { result[f.key] = f.options == null ? controllers[f.key]!.text.trim() : selections[f.key]; } Navigator.pop(context, result); }, icon: const Icon(Icons.save), label: const Text('حفظ'))]));
}
