import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.hasData ? const ExpenseHomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

class ExpenseHomeScreen extends StatefulWidget {
  const ExpenseHomeScreen({super.key});

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final User? _user = FirebaseAuth.instance.currentUser;
  double _budget = 1000.0;

  Color _getCategoryColor(String category) {
  switch (category) {
    case 'Food': return Colors.orange;
    case 'Transport': return Colors.blue;
    case 'Rent': return Colors.red;
    case 'Entertainment': return Colors.purple;
    default: return Colors.green;
  }
}

  Future<void> _deleteExpense(String docId) async {
    await FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
  }

  void _showAddExpenseModal(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Food';
    final categories = ['Food', 'Transport', 'Rent', 'Entertainment', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setModalState(() => selectedCategory = val!),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('expenses').add({
                      'userId': _user?.uid,
                      'title': titleController.text,
                      'amount': double.tryParse(amountController.text) ?? 0,
                      'category': selectedCategory,
                      'date': DateTime.now().toIso8601String(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tracker'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').where('userId', isEqualTo: _user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          double totalSpent = docs.fold(0.0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as num).toDouble());
          
          Map<String, double> catData = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            catData[data['category'] ?? 'Other'] = (catData[data['category'] ?? 'Other'] ?? 0) + (data['amount'] as num).toDouble();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Set Monthly Budget'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() => _budget = double.tryParse(val) ?? 1000.0),
                ),
              ),
              SizedBox(
  height: 180,
  child: PieChart(
    PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: catData.entries.map((e) {
        return PieChartSectionData(
          color: _getCategoryColor(e.key),
          value: e.value,
          title: e.key,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        );
      }).toList(),
    ),
  ),
),
              Text("Remaining: ${_currencyFormat.format(_budget - totalSpent)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['title']),
                      subtitle: Text(data['category'] ?? 'General'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteExpense(docs[i].id)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddExpenseModal(context), child: const Icon(Icons.add)),
    );
  }
}