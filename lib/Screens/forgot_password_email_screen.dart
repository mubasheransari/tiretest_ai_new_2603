import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Screens/reset_password_screen.dart';

import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';

class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  State<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  _BackPillButton(s: s),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      "Forgot Password",
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18 * s,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<AuthBloc, AuthState>(
                listenWhen: (p, c) =>
                    p.forgotEmailStatus != c.forgotEmailStatus,
                listener: (context, state) {
                  if (state.forgotEmailStatus == ForgotEmailStatus.success &&
                      state.verifyEmailResponse != null) {
                    final userId = state.verifyEmailResponse!.userId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordResetScreen(userId: userId),
                      ),
                    );
                  }

                  if (state.forgotEmailStatus == ForgotEmailStatus.failure) {
                    final msg =
                        state.forgotEmailError ?? "Email verification failed";
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                builder: (context, state) {
                  final loading =
                      state.forgotEmailStatus == ForgotEmailStatus.loading;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Enter your email",
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 14.5 * s,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 14.5 * s,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                                decoration: InputDecoration(
                                  hintText: "example@gmail.com",
                                  hintStyle: TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 13.5 * s,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF6F7FA),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF3B82F6),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: _GradientButton(
                            text: loading ? "Verifying..." : "Verify Email",
                            enabled: !loading,
                            onTap: () {
                              context.read<AuthBloc>().add(
                                    ForgotPasswordVerifyEmailRequested(
                                      email: _emailCtrl.text,
                                    ),
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F2F6)),
      ),
      child: child,
    );
  }
}

class _BackPillButton extends StatelessWidget {
  const _BackPillButton({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22 * s,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFF6D63FF).withOpacity(.35),
                      const Color(0xFF2DA3FF).withOpacity(.35),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
