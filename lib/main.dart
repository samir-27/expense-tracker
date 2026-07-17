import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  Future<void> _signOut() async => await FirebaseAuth.instance.signOut();

  Future<void> _deleteExpense(String docId) async {
    await FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
  }

  void _showAddExpenseModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Enter a title' : null,
              ),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v!) == null ? 'Enter a valid number' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    print("Attempting to add for UID: $uid"); // Check console
                    await FirebaseFirestore.instance.collection('expenses').add({
                      'userId': uid,
                      'title': titleController.text,
                      'amount': double.parse(amountController.text),
                      'date': DateTime.now().toIso8601String(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Add Expense'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .where('userId', isEqualTo: uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final docs = snapshot.data?.docs ?? [];
          final total = docs.fold(0.0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as num).toDouble());

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Total Spent: ${_currencyFormat.format(total)}", 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: docs.isEmpty 
                    ? const Center(child: Text("No expenses yet. Add some!"))
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              title: Text(data['title'] ?? 'Untitled'),
                              subtitle: Text(data['date'] != null ? _dateFormat.format(DateTime.parse(data['date'])) : ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExpense(docs[index].id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}