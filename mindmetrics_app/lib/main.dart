import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- 1. Import dotenv
import 'firebase_options.dart';
import 'screens/login_screen.dart'; 

void main() async {
  // 1. Ensure the Flutter engine is ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Load the environment variables from the .env file <-- 2. Initialize dotenv
  await dotenv.load(fileName: ".env");
  
  // 3. Initialize Firebase using your newly generated keys
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindMetrics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Roboto',
      ),
      // Boot directly into the Login Screen
      home: const LoginScreen(),
    );
  }
}