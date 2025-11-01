import 'package:flutter/material.dart';
import 'package:crewning/features/auth/presentation/auth_screen.dart';
import 'package:crewning/features/root/presentation/crewning_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;

        if (session == null) {
          return const AuthScreen();
        }

        return const CrewningHome();
      },
    );
  }
}
