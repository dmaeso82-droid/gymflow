import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

const String demoGymId = 'default_gym';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GymFlowApp());
}

class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingPage();
          }
          if (snapshot.hasData) {
            return const RoleGatePage();
          }
          return const AuthPage();
        },
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool registerMode = false;
  bool loading = false;
  String selectedRole = 'trainer';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showSnack('Introduce email y contraseña.');
      return;
    }

    if (registerMode && name.isEmpty) {
      showSnack('Introduce tu nombre.');
      return;
    }

    setState(() => loading = true);

    try {
      if (registerMode) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = credential.user!.uid;
        final db = FirebaseFirestore.instance;

        await db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': selectedRole,
          'gymId': demoGymId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await db.collection('gyms').doc(demoGymId).set({
          'name': 'GymFlow Demo',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await db
            .collection('gyms')
            .doc(demoGymId)
            .collection('members')
            .doc(uid)
            .set({
          'name': name,
          'email': email,
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String authMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ese email ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'Email no válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.fitness_center, size: 52, color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'GymFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registerMode ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    if (registerMode) ...[
                      AppTextField(controller: nameController, label: 'Nombre'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        dropdownColor: const Color(0xFF0F172A),
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'trainer', child: Text('Entrenador')),
                          DropdownMenuItem(value: 'user', child: Text('Usuario')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: passwordController,
                      label: 'Contraseña',
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(registerMode ? 'Crear cuenta' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Ya tengo cuenta' : 'Crear cuenta nueva'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleGatePage extends StatelessWidget {
  const RoleGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final uid = currentUser.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingPage();

        final data = snapshot.data!.data();
        if (data == null) return const AuthPage();

        final role = data['role'] as String? ?? 'user';
        final gymId = data['gymId'] as String? ?? demoGymId;
        final name = data['name'] as String? ?? 'Usuario';
        final email = (data['email'] as String? ?? currentUser.email ?? '').toLowerCase();

        if (role == 'trainer') {
          return TrainerHomePage(gymId: gymId, trainerName: name);
        }

        return UserHomePage(
          gymId: gymId,
          userId: uid,
          userName: name,
          userEmail: email,
        );
      },
    );
  }
}

class TrainerHomePage extends StatefulWidget {
  final String gymId;
  final String trainerName;

  const TrainerHomePage({super.key, required this.gymId, required this.trainerName});

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  final clientNameController = TextEditingController();
  final clientEmailController = TextEditingController();
  final clientGoalController = TextEditingController();
  final routineTitleController = TextEditingController();

  String? selectedClientId;
  String searchText = '';

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routines');

  @override
  void dispose() {
    clientNameController.dispose();
    clientEmailController.dispose();
    clientGoalController.dispose();
    routineTitleController.dispose();
    super.dispose();
  }

  Future<void> addClient() async {
    final name = clientNameController.text.trim();
    final email = clientEmailController.text.trim().toLowerCase();
    final goal = clientGoalController.text.trim();

    if (name.isEmpty) {
      showSnack('Introduce el nombre del cliente.');
      return;
    }

    if (email.isEmpty) {
      showSnack('Introduce el email del cliente.');
      return;
    }

    final doc = await clientsRef.add({
      'name': name,
      'email': email,
      'goal': goal.isEmpty ? 'Objetivo pendiente' : goal,
      'level': 'Nuevo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      selectedClientId = doc.id;
      clientNameController.clear();
      clientEmailController.clear();
      clientGoalController.clear();
    });
  }

  Future<void> addRoutine(List<QueryDocumentSnapshot<Map<String, dynamic>>> clients) async {
    final title = routineTitleController.text.trim();

    if (title.isEmpty) {
      showSnack('Introduce el nombre de la rutina.');
      return;
    }

    if (selectedClientId == null) {
      showSnack('Selecciona un cliente.');
      return;
    }

	if (clients.isEmpty) {
		showSnack('No hay clientes.');
		return;
	}

	QueryDocumentSnapshot<Map<String, dynamic>> selectedClientDoc =
		clients.first;

	for (final doc in clients) {
		if (doc.id == selectedClientId) {
			selectedClientDoc = doc;
			break;
		}
	}
    final selectedClient = selectedClientDoc.data();

    await routinesRef.add({
      'title': title,
      'clientId': selectedClientDoc.id,
      'clientName': selectedClient['name'] ?? 'Sin cliente',
      'clientEmail': (selectedClient['email'] ?? '').toString().toLowerCase(),
      'day': 'Nuevo día',
      'notes': 'Añade observaciones para el usuario.',
      'exercises': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    routineTitleController.clear();
  }

  Future<void> addExercise(String routineId, List<dynamic> currentExercises) async {
    final result = await showExerciseSheet(context);
    if (result == null) return;

    final newExercise = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': result.name,
      'sets': result.sets,
      'reps': result.reps,
      'weight': result.weight,
      'rest': result.rest,
      'done': false,
    };

    await routinesRef.doc(routineId).update({
      'exercises': [...currentExercises, newExercise],
    });
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) map['done'] = done;
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  Future<void> deleteExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    final updated = exercises.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return map['id'] != exerciseId;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · ${widget.trainerName}'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeaderCard(subtitle: 'Panel de entrenador'),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, clientSnapshot) {
                final clients = clientSnapshot.data?.docs ?? [];

                if (selectedClientId == null && clients.isNotEmpty) {
                  selectedClientId = clients.first.id;
                }

                return Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(icon: Icons.person_add, title: 'Crear cliente'),
                          const SizedBox(height: 12),
                          AppTextField(controller: clientNameController, label: 'Nombre del cliente'),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: clientEmailController,
                            label: 'Email del cliente',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: clientGoalController,
                            label: 'Objetivo',
                            hint: 'Ej: Fuerza, pérdida de grasa...',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: addClient,
                              icon: const Icon(Icons.add),
                              label: const Text('Crear cliente'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (clients.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: selectedClientId,
                              dropdownColor: const Color(0xFF0F172A),
                              decoration: const InputDecoration(
                                labelText: 'Cliente seleccionado',
                                border: OutlineInputBorder(),
                              ),
                              items: clients.map((doc) {
                                final data = doc.data();
                                final name = data['name'] ?? 'Sin nombre';
                                final email = data['email'] ?? 'Sin email';
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text('$name · $email'),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedClientId = value),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(icon: Icons.playlist_add, title: 'Crear rutina'),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: routineTitleController,
                            label: 'Nombre de la rutina',
                            hint: 'Ej: Pecho y tríceps',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: clients.isEmpty ? null : () => addRoutine(clients),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear rutina'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => setState(() => searchText = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Buscar rutina o cliente',
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: routinesRef.orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, routineSnapshot) {
                        if (routineSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final clientNames = {
                          for (final doc in clients) doc.id: doc.data()['name'] ?? 'Sin cliente'
                        };

                        final routines = (routineSnapshot.data?.docs ?? []).where((doc) {
                          final data = doc.data();
                          final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? '').toString();
                          final clientEmail = (data['clientEmail'] ?? '').toString();
                          final fullText = '${data['title'] ?? ''} $clientName $clientEmail'.toLowerCase();
                          return fullText.contains(searchText.toLowerCase());
                        }).toList();

                        if (routines.isEmpty) {
                          return const AppCard(child: Center(child: Text('Todavía no hay rutinas.')));
                        }

                        return Column(
                          children: routines.map((doc) {
                            final data = doc.data();
                            final exercises = List<dynamic>.from(data['exercises'] ?? []);
                            final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? 'Sin cliente').toString();

                            return RoutineCard(
                              title: data['title'] ?? 'Sin título',
                              day: data['day'] ?? 'Sin día',
                              notes: data['notes'] ?? '',
                              clientName: clientName,
                              exercises: exercises,
                              trainerMode: true,
                              onAddExercise: () => addExercise(doc.id, exercises),
                              onToggleExercise: (exerciseId, done) => updateExerciseDone(doc.id, exercises, exerciseId, done),
                              onDeleteExercise: (exerciseId) => deleteExercise(doc.id, exercises, exerciseId),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UserHomePage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserHomePage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  Future<void> saveWorkoutLog({
    required String routineId,
    required String routineTitle,
    required Map<String, dynamic> exercise,
    required int weight,
    required int reps,
  }) async {
    await logsRef.add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'routineId': routineId,
      'routineTitle': routineTitle,
      'exerciseId': exercise['id'] ?? '',
      'exercise': exercise['name'] ?? 'Ejercicio',
      'plannedSets': exercise['sets'] ?? '',
      'plannedReps': exercise['reps'] ?? '',
      'plannedWeight': exercise['weight'] ?? '',
      'weight': weight,
      'reps': reps,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> showWorkoutLogDialog(
    BuildContext context,
    String routineId,
    String routineTitle,
    List<dynamic> exercises,
    String exerciseId,
  ) async {
    final exercise = exercises
        .map((item) => Map<String, dynamic>.from(item as Map))
        .firstWhere((item) => item['id'] == exerciseId);

    final weightText = (exercise['weight'] ?? '').toString();
    final repsText = (exercise['reps'] ?? '').toString();
    final suggestedWeight = RegExp(r'\d+').firstMatch(weightText)?.group(0) ?? '';
    final suggestedReps = RegExp(r'\d+').firstMatch(repsText)?.group(0) ?? '';

    final weightController = TextEditingController(text: suggestedWeight);
    final repsController = TextEditingController(text: suggestedReps);

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text('Registrar ${exercise['name'] ?? 'ejercicio'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: weightController,
                label: 'Peso realizado (kg)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: repsController,
                label: 'Repeticiones realizadas',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final weight = int.tryParse(weightController.text.trim());
                final reps = int.tryParse(repsController.text.trim());

                if (weight == null || reps == null || weight < 0 || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce peso y repeticiones válidas.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {'weight': weight, 'reps': reps});
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar serie'),
            ),
          ],
        );
      },
    );

    weightController.dispose();
    repsController.dispose();

    if (result == null) return;

    await saveWorkoutLog(
      routineId: routineId,
      routineTitle: routineTitle,
      exercise: exercise,
      weight: result['weight']!,
      reps: result['reps']!,
    );

    await updateExerciseDone(routineId, exercises, exerciseId, true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serie guardada en el historial.')),
      );
    }
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) map['done'] = done;
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · $userName'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeaderCard(subtitle: 'Panel de usuario'),
            const SizedBox(height: 16),
            AppCard(
              child: Text(
                'Mostrando solo rutinas asignadas a: $userEmail',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routines = snapshot.data?.docs ?? [];

                if (routines.isEmpty) {
                  return const AppCard(
                    child: Center(
                      child: Text(
                        'Todavía no tienes rutinas asignadas. Comprueba que el entrenador haya creado el cliente con este mismo email.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: routines.map((doc) {
                    final data = doc.data();
                    final exercises = List<dynamic>.from(data['exercises'] ?? []);

                    return RoutineCard(
                      title: data['title'] ?? 'Sin título',
                      day: data['day'] ?? 'Sin día',
                      notes: data['notes'] ?? '',
                      clientName: 'Mi rutina',
                      exercises: exercises,
                      trainerMode: false,
                      onToggleExercise: (exerciseId, done) => updateExerciseDone(doc.id, exercises, exerciseId, done),
                      onLogWorkout: (exerciseId) => showWorkoutLogDialog(
                        context,
                        doc.id,
                        data['title'] ?? 'Sin título',
                        exercises,
                        exerciseId,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            PersonalRecords(
              logsRef: logsRef,
              userId: userId,
            ),
            const SizedBox(height: 16),
            RecentWorkoutHistory(
              logsRef: logsRef,
              userId: userId,
            ),
          ],
        ),
      ),
    );
  }
}



class PersonalRecords extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const PersonalRecords({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    return 'Fecha pendiente';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final logs = snapshot.data?.docs ?? [];

        if (logs.isEmpty) {
          return const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.emoji_events, title: 'Récords personales'),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay datos suficientes para calcular récords personales.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final Map<String, Map<String, dynamic>> records = {};

        for (final doc in logs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          if (exercise.isEmpty) continue;

          final weight = intValue(data['weight']);
          final reps = intValue(data['reps']);
          final createdAt = data['createdAt'];
          final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';

          final current = records[exercise];

          if (current == null ||
              weight > intValue(current['weight']) ||
              (weight == intValue(current['weight']) && reps > intValue(current['reps']))) {
            records[exercise] = {
              'exercise': exercise,
              'weight': weight,
              'reps': reps,
              'createdAt': createdAt,
              'routineTitle': routineTitle,
              'series': 1,
            };
          } else {
            current['series'] = intValue(current['series']) + 1;
          }
        }

        final recordList = records.values.toList();

        recordList.sort((a, b) {
          final weightCompare = intValue(b['weight']).compareTo(intValue(a['weight']));
          if (weightCompare != 0) return weightCompare;

          final repsCompare = intValue(b['reps']).compareTo(intValue(a['reps']));
          if (repsCompare != 0) return repsCompare;

          return a['exercise'].toString().compareTo(b['exercise'].toString());
        });

        final bestOverall = recordList.isEmpty ? null : recordList.first;
        final bestOverallText = bestOverall == null
            ? '-'
            : '${bestOverall['weight']} kg · ${bestOverall['exercise']}';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.emoji_events, title: 'Récords personales'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${logs.length} series registradas'),
                  InfoChip(text: '${recordList.length} ejercicios'),
                  InfoChip(text: 'Mejor marca: $bestOverallText'),
                ],
              ),
              const SizedBox(height: 14),
              if (recordList.isEmpty)
                const Text(
                  'Todavía no hay récords calculables.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...recordList.take(10).map((record) {
                  final exercise = record['exercise']?.toString() ?? 'Ejercicio';
                  final weight = intValue(record['weight']);
                  final reps = intValue(record['reps']);
                  final routineTitle = record['routineTitle']?.toString() ?? 'Rutina';
                  final date = formatDate(record['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.amberAccent),
                      ),
                      title: Text(
                        exercise,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(routineTitle, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                InfoChip(text: 'PR $weight kg'),
                                InfoChip(text: '$reps reps'),
                                InfoChip(text: date),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class RecentWorkoutHistory extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const RecentWorkoutHistory({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }

    return 'Fecha pendiente';
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final logs = [...(snapshot.data?.docs ?? [])];

        logs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final recentLogs = logs.take(20).toList();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.history, title: 'Historial reciente'),
              const SizedBox(height: 12),
              if (recentLogs.isEmpty)
                const Text(
                  'Todavía no hay entrenamientos registrados.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...recentLogs.map((doc) {
                  final data = doc.data();
                  final exercise = data['exercise']?.toString() ?? 'Ejercicio';
                  final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';
                  final weight = data['weight']?.toString() ?? '-';
                  final reps = data['reps']?.toString() ?? '-';
                  final date = formatDate(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.monitor_weight, color: Colors.greenAccent),
                      ),
                      title: Text(
                        exercise,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(routineTitle, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                InfoChip(text: '$weight kg'),
                                InfoChip(text: '$reps reps'),
                                InfoChip(text: date),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

int routineProgress(List<dynamic> exercises) {
  if (exercises.isEmpty) return 0;

  final done = exercises.where((item) {
    final map = Map<String, dynamic>.from(item as Map);
    return map['done'] == true;
  }).length;

  return ((done / exercises.length) * 100).round();
}

class ExerciseInput {
  final String name;
  final int sets;
  final String reps;
  final String weight;
  final String rest;

  ExerciseInput({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.rest,
  });
}

Future<ExerciseInput?> showExerciseSheet(BuildContext context) async {
  final nameController = TextEditingController();
  final setsController = TextEditingController(text: '3');
  final repsController = TextEditingController(text: '10');
  final weightController = TextEditingController();
  final restController = TextEditingController(text: '60 s');

  return showModalBottomSheet<ExerciseInput>(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(icon: Icons.fitness_center, title: 'Añadir ejercicio'),
            const SizedBox(height: 16),
            AppTextField(controller: nameController, label: 'Nombre del ejercicio'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: setsController,
                    label: 'Series',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: repsController, label: 'Reps')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: weightController,
                    label: 'Peso',
                    hint: 'Ej: 40 kg',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: restController, label: 'Descanso')),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(
                  context,
                  ExerciseInput(
                    name: name,
                    sets: int.tryParse(setsController.text.trim()) ?? 1,
                    reps: repsController.text.trim(),
                    weight: weightController.text.trim(),
                    rest: restController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ],
        ),
      );
    },
  );
}

class RoutineCard extends StatelessWidget {
  final String title;
  final String day;
  final String notes;
  final String clientName;
  final List<dynamic> exercises;
  final bool trainerMode;
  final VoidCallback? onAddExercise;
  final void Function(String exerciseId, bool done) onToggleExercise;
  final void Function(String exerciseId)? onDeleteExercise;
  final void Function(String exerciseId)? onLogWorkout;

  const RoutineCard({
    super.key,
    required this.title,
    required this.day,
    required this.notes,
    required this.clientName,
    required this.exercises,
    required this.trainerMode,
    required this.onToggleExercise,
    this.onAddExercise,
    this.onDeleteExercise,
    this.onLogWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final progress = routineProgress(exercises);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: Colors.white60),
              const SizedBox(width: 6),
              Expanded(child: Text('$day · $clientName', style: const TextStyle(color: Colors.white60))),
              Chip(
                label: Text('$progress%'),
                backgroundColor: Colors.greenAccent.withOpacity(0.15),
                side: BorderSide.none,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(notes, style: const TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white12,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 16),
          if (exercises.isEmpty)
            const Text('Esta rutina todavía no tiene ejercicios.', style: TextStyle(color: Colors.white70))
          else
            ...exercises.map((item) {
              final exercise = Map<String, dynamic>.from(item as Map);
              return ExerciseTile(
                exercise: exercise,
                trainerMode: trainerMode,
                onToggle: () {
                  final exerciseId = exercise['id'] as String;
                  if (trainerMode) {
                    onToggleExercise(
                      exerciseId,
                      !(exercise['done'] == true),
                    );
                  } else if (onLogWorkout != null) {
                    onLogWorkout!(exerciseId);
                  } else {
                    onToggleExercise(
                      exerciseId,
                      !(exercise['done'] == true),
                    );
                  }
                },
                onDelete: onDeleteExercise == null ? null : () => onDeleteExercise!(exercise['id'] as String),
              );
            }),
          if (trainerMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExerciseTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool trainerMode;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.trainerMode,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = exercise['done'] == true;
    final name = exercise['name'] as String? ?? 'Ejercicio';
    final sets = exercise['sets']?.toString() ?? '-';
    final reps = exercise['reps']?.toString() ?? '-';
    final weight = exercise['weight']?.toString() ?? '';
    final rest = exercise['rest']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: IconButton(
          onPressed: onToggle,
          icon: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.greenAccent : Colors.white54,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            color: done ? Colors.greenAccent : Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoChip(text: '$sets series'),
              InfoChip(text: '$reps reps'),
              if (weight.trim().isNotEmpty) InfoChip(text: weight),
              InfoChip(text: 'Descanso $rest'),
            ],
          ),
        ),
        trailing: trainerMode
            ? IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              )
            : const Icon(Icons.play_circle_outline, color: Colors.white54),
      ),
    );
  }
}

class HeaderCard extends StatelessWidget {
  final String subtitle;

  const HeaderCard({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(subtitle, style: const TextStyle(color: Colors.greenAccent)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Rutinas claras para entrenadores y usuarios',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea clientes, asigna rutinas y registra el progreso con datos guardados en Firebase.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text;

  const InfoChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFF0F172A),
      side: BorderSide.none,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.greenAccent),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const AppCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF020617),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
