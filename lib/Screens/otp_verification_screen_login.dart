import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/splash_screen.dart';

class OtpVerificationScreenLogin extends StatefulWidget {
  const OtpVerificationScreenLogin({
    super.key,
    required this.targetText, // ✅ email here
    this.title = 'OTP Verification',
    this.subtitle = 'Enter the 6-digit code we sent to',
    this.otpLength = 6,
    this.resendSeconds = 30,
    this.expiryMinutes = 10, // ✅ expiry is 10 minutes
  });

  final String targetText;
  final String title;
  final String subtitle;
  final int otpLength;
  final int resendSeconds;
  final int expiryMinutes;

  @override
  State<OtpVerificationScreenLogin> createState() => _OtpVerificationScreenLoginState();
}

class _OtpVerificationScreenLoginState extends State<OtpVerificationScreenLogin> {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _nodes;

  bool _verifying = false;

  // resend
  int _remaining = 0;
  Timer? _timer;

  // expiry
  late int _otpExpireRemaining;
  Timer? _expireTimer;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.otpLength, (_) => TextEditingController());
    _nodes = List.generate(widget.otpLength, (_) => FocusNode());

    _startResendTimer();
    _startExpiryTimer(); // ✅ 10 min expiry countdown

    // optional: focus first box on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expireTimer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _remaining = widget.resendSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  void _startExpiryTimer() {
    _expireTimer?.cancel();
    _otpExpireRemaining = widget.expiryMinutes * 60; // ✅ 10 minutes

    _expireTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_otpExpireRemaining <= 1) {
        t.cancel();
        setState(() => _otpExpireRemaining = 0);
      } else {
        setState(() => _otpExpireRemaining -= 1);
      }
    });
  }

  String get _otp => _ctrls.map((e) => e.text.trim()).join();

  bool get _isComplete =>
      _otp.length == widget.otpLength && !_otp.contains(RegExp(r'[^0-9]'));

  bool get _isExpired => _otpExpireRemaining <= 0;

  String get _expiryText {
    final m = _otpExpireRemaining ~/ 60;
    final s = _otpExpireRemaining % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _setOtpFromPaste(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < widget.otpLength) return;

    for (int i = 0; i < widget.otpLength; i++) {
      _ctrls[i].text = digits[i];
    }

    _nodes.last.unfocus();
    setState(() {});
  }

  void _onChanged(int idx, String v) {
    if (v.length > 1) {
      _setOtpFromPaste(v);
      return;
    }

    if (v.isNotEmpty) {
      if (idx < widget.otpLength - 1) {
        _nodes[idx + 1].requestFocus();
      } else {
        _nodes[idx].unfocus();
      }
    }

    setState(() {});
  }

  // ✅ Key handling WITHOUT FocusNode parent conflict
  KeyEventResult _onKey(int idx, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_ctrls[idx].text.isEmpty && idx > 0) {
        _ctrls[idx - 1].text = '';
        _nodes[idx - 1].requestFocus();
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _clearOtp() {
    for (final c in _ctrls) c.clear();
    _nodes.first.requestFocus();
    setState(() {});
  }

  Future<void> _verify() async {
    if (!_isComplete || _verifying) return;

    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired. Please resend OTP.')),
      );
      return;
    }

    final otpInt = int.tryParse(_otp) ?? 0;
    if (otpInt <= 0) return;

    setState(() => _verifying = true);

    // ✅ BLoC call (same pattern)
    context.read<AuthBloc>().add(
          VerifyOtpRequested(
            email: widget.targetText.trim(),
            otp: otpInt,
          ),
        );
  }

  Future<void> _resend() async {
    if (_remaining > 0) return;

    // ✅ If you add resend event later, call it here.
    // For now keep same behavior: restart timers + message.
    _startResendTimer();
    _startExpiryTimer();
    _clearOtp();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;
    final pad = MediaQuery.of(context).padding;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.verifyOtpStatus != c.verifyOtpStatus ||
          p.verifyOtpError != c.verifyOtpError,
      listener: (context, state) {
        if (state.verifyOtpStatus == VerifyOtpStatus.failure) {
          if (mounted) setState(() => _verifying = false);

          final msg = state.verifyOtpError ?? "OTP verification failed";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }

        if (state.verifyOtpStatus == VerifyOtpStatus.success) {
          if (mounted) setState(() => _verifying = false);

          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FA),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10 + pad.top * 0.0, 16, 10),
                child: Row(
                  children: [
                    _BackPillButton(s: s),
                    SizedBox(width: 12 * s),
                    Expanded(
                      child: Text(
                        widget.title,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // title block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 13.5 * s,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6A6F7B),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.targetText,
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 16 * s,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF111827),
                                letterSpacing: .1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // OTP block
                      Container(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter OTP',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 14.5 * s,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ✅ expiry line
                            Row(
                              children: [
                                Text(
                                  _isExpired
                                      ? "OTP expired. Please resend."
                                      : "OTP expires in $_expiryText",
                                  style: TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 12.8 * s,
                                    fontWeight: FontWeight.w800,
                                    color: _isExpired
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6A6F7B),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: List.generate(widget.otpLength, (i) {
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i == widget.otpLength - 1 ? 0 : 10,
                                    ),
                                    child: Focus(
                                      onKeyEvent: (_, event) => _onKey(i, event),
                                      child: TextField(
                                        controller: _ctrls[i],
                                        focusNode: _nodes[i],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onChanged: (v) => _onChanged(i, v),
                                        enabled: !_verifying && !_isExpired,
                                        style: TextStyle(
                                          fontFamily: 'ClashGrotesk',
                                          fontSize: 18 * s,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF111827),
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          filled: true,
                                          fillColor: const Color(0xFFF6F7FA),
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 14 * s,
                                          ),
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
                                    ),
                                  ),
                                );
                              }),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Text(
                                  _remaining > 0
                                      ? 'Resend in ${_remaining}s'
                                      : "Didn't receive the code?",
                                  style: TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 13 * s,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6A6F7B),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _remaining > 0 ? null : _resend,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF3B82F6),
                                    textStyle: TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13 * s,
                                    ),
                                  ),
                                  child: const Text('Resend'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: _GradientButton(
                          text: _verifying ? 'Verifying...' : 'Verify OTP',
                          enabled: _isComplete && !_verifying && !_isExpired,
                          onTap: _verify,
                        ),
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'By continuing, you agree to our policies.',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 12.5 * s,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- Theme widgets -----------------

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
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
