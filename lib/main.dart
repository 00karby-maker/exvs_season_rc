import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';

part 'main.g.dart';

@HiveType(typeId: 0)
class MatchRecord extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String machine;

  @HiveField(2)
  int wins;

  @HiveField(3)
  int losses;

  MatchRecord({
    required this.date,
    required this.machine,
    required this.wins,
    required this.losses,
  });

  int get total => wins + losses;
  double get winRate => total == 0 ? 0 : wins / total;
}

/// 勝率色
Color getRateColor(double rate) {
  final p = rate * 100;
  if (p >= 90) return Colors.amber;
  if (p >= 70) return Colors.grey;
  if (p >= 50) return Colors.green;
  if (p >= 30) return Colors.blue;
  return Colors.red;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MatchRecordAdapter());
  await Hive.openBox<MatchRecord>('records');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final pages = const [
    InputPage(),
    HistoryPage(),
    StatsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: "入力"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "履歴"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "集計"),
        ],
      ),
    );
  }
}

List<String> getMachines() {
  final records = Hive.box<MatchRecord>('records').values;
  return records.map((e) => e.machine).toSet().toList();
}

//////////////////////////////////////////////////
// 入力ページ（試合数＋勝ち）
//////////////////////////////////////////////////
class InputPage extends StatefulWidget {
  const InputPage({super.key});
  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  DateTime date = DateTime.now();

  final machineCtrl = TextEditingController();
  final totalCtrl = TextEditingController();
  final winCtrl = TextEditingController();

  int get total => int.tryParse(totalCtrl.text) ?? 0;
  int get wins => int.tryParse(winCtrl.text) ?? 0;
  int get losses => (total - wins).clamp(0, 9999);

  double get winRate => total == 0 ? 0 : wins / total;

  @override
  Widget build(BuildContext context) {
    final machines = getMachines();

    return Scaffold(
      appBar: AppBar(title: const Text("入力")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: getRateColor(winRate),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      child: Text(date.toString().split(" ")[0]),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => date = d);
                      },
                    ),

                    const SizedBox(height: 10),

                    Autocomplete<String>(
                      optionsBuilder: (v) => machines.where((m) =>
                          m.toLowerCase().contains(v.text.toLowerCase())),
                      onSelected: (v) => machineCtrl.text = v,
                      fieldViewBuilder: (c, ctrl, f, s) {
                        return TextField(
                          controller: ctrl,
                          focusNode: f,
                          decoration:
                              const InputDecoration(labelText: "機体名"),
                          onChanged: (v) => machineCtrl.text = v,
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: "試合数"),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: winCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: "勝ち"),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "負け: $losses  勝率: ${(winRate * 100).toStringAsFixed(1)}%",
                      style: TextStyle(color: getRateColor(winRate)),
                    ),

                    ElevatedButton(
                      onPressed: () {
                        if (machineCtrl.text.isEmpty) return;
                        if (wins > total) return;

                        Hive.box<MatchRecord>('records').add(
                          MatchRecord(
                            date: date,
                            machine: machineCtrl.text,
                            wins: wins,
                            losses: losses,
                          ),
                        );

                        totalCtrl.clear();
                        winCtrl.clear();
                        setState(() {});
                      },
                      child: const Text("保存"),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////
// 履歴（表示＋編集も対応）
//////////////////////////////////////////////////
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final list = Hive.box<MatchRecord>('records').values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text("履歴")),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final r = list[i];

          return Card(
            child: ListTile(
              title: Text(r.machine),
              subtitle: Text(
                  "${r.date.toString().split(" ")[0]} 試合:${r.total} 勝:${r.wins}"),
              onTap: () => editDialog(r),
            ),
          );
        },
      ),
    );
  }

  void editDialog(MatchRecord r) {
    final machineCtrl = TextEditingController(text: r.machine);
    final totalCtrl = TextEditingController(text: r.total.toString());
    final winCtrl = TextEditingController(text: r.wins.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("編集"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: machineCtrl,
              decoration: const InputDecoration(labelText: "機体名"),
            ),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "試合数"),
            ),
            TextField(
              controller: winCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "勝ち"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final total = int.tryParse(totalCtrl.text) ?? r.total;
              final wins = int.tryParse(winCtrl.text) ?? r.wins;

              if (wins > total) return;

              r.machine = machineCtrl.text;
              r.wins = wins;
              r.losses = total - wins;

              r.save();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("保存"),
          )
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////
// 集計（そのまま）
//////////////////////////////////////////////////
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class Summary {
  String machine;
  int wins;
  int losses;

  Summary(this.machine, this.wins, this.losses);

  int get total => wins + losses;
  double get winRate => total == 0 ? 0 : wins / total;
}

class _StatsPageState extends State<StatsPage> {
  final machineCtrl = TextEditingController();
  DateTime? from;
  DateTime? to;

  int totalMatches = 0;
  int totalWins = 0;
  int totalLosses = 0;

  double get totalRate =>
      totalMatches == 0 ? 0 : totalWins / totalMatches;

  Map<String, Summary> summary = {};

  void calc() {
    final records = Hive.box<MatchRecord>('records').values;

    summary.clear();
    totalMatches = 0;
    totalWins = 0;
    totalLosses = 0;

    final filterMachine = machineCtrl.text.trim();

    if (filterMachine.isNotEmpty &&
        !getMachines().contains(filterMachine)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("存在しない機体です")),
      );
      return;
    }

    for (var r in records) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);

      /// 日付フィルタ
      if (from != null) {
        final f = DateTime(from!.year, from!.month, from!.day);
        if (rDate.isBefore(f)) continue;
      }

      if (to != null) {
        final t = DateTime(to!.year, to!.month, to!.day);
        if (rDate.isAfter(t)) continue;
      }

      /// 機体フィルタ
      if (filterMachine.isNotEmpty && r.machine != filterMachine) {
        continue;
      }

      totalMatches += r.total;
      totalWins += r.wins;
      totalLosses += r.losses;

      final key = r.machine;

      summary.putIfAbsent(
  key,
  () => Summary(key, 0, 0),
);

summary[key]!.wins += r.wins;
summary[key]!.losses += r.losses;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("集計")),
      body: Column(
        children: [
          /// 🔷 フィルタ＋合計（固定エリア）
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  /// 機体検索
                  Autocomplete<String>(
                    optionsBuilder: (v) {
                      if (v.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return getMachines().where((m) =>
                          m.toLowerCase().contains(v.text.toLowerCase()));
                    },
                    onSelected: (v) => machineCtrl.text = v,
                    fieldViewBuilder: (c, ctrl, f, s) {
                      return TextField(
                        controller: ctrl,
                        focusNode: f,
                        decoration:
                            const InputDecoration(labelText: "機体名"),
                        onChanged: (v) => machineCtrl.text = v,
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  /// 日付フィルタ
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => from = d);
                          },
                          child: Text(from == null
                              ? "開始日"
                              : from.toString().split(" ")[0]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => to = d);
                          },
                          child: Text(to == null
                              ? "終了日"
                              : to.toString().split(" ")[0]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          final d = DateTime.now();
                          final today =
                              DateTime(d.year, d.month, d.day);
                          setState(() {
                            from = today;
                            to = today;
                          });
                        },
                        child: const Text("今日"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// 集計ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: calc,
                      child: const Text("集計"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 🔶 合計表示（ここに固定）
                  if (totalMatches > 0)
                    Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: getRateColor(totalRate),
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          "合計 (${machineCtrl.text.isEmpty ? "全体" : machineCtrl.text})",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "試合:$totalMatches 勝:$totalWins 負:$totalLosses",
                        ),
                        trailing: Text(
                          "${(totalRate * 100).toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: getRateColor(totalRate),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          /// 🔥 結果リスト（スクロール）
          Expanded(
            child: ListView.builder(
              itemCount: summary.length,
              itemBuilder: (context, i) {
                final r = summary.values.elementAt(i);

                return Card(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: getRateColor(r.winRate),
                      width: 2,
                    ),
                  ),
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(r.machine),
                    subtitle: Text(
                        "試合:${r.total} 勝:${r.wins} 負:${r.losses}"),
                    trailing: Text(
                      "${(r.winRate * 100).toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: getRateColor(r.winRate),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}