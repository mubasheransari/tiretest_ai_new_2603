import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ios_tiretest_ai/Screens/reset_password_screen.dart';


class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    required this.userId,
    this.otpLength = 6,
    this.resendSeconds = 30,
  });

  final String email;
  final String userId;
  final int otpLength;
  final int resendSeconds;

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _nodes;

  bool _verifying = false;
  int _remaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.otpLength, (_) => TextEditingController());
    _nodes = List.generate(widget.otpLength, (_) => FocusNode());
    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  String get _otp => _ctrls.map((e) => e.text.trim()).join();

  bool get _isComplete =>
      _otp.length == widget.otpLength && !_otp.contains(RegExp(r'[^0-9]'));

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

  Future<void> _verify() async {
    if (!_isComplete || _verifying) return;
    setState(() => _verifying = true);

    // ✅ If you have OTP verify API, call it here
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _verifying = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordResetScreen(
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _resend() async {
    if (_remaining > 0) return;

    // ✅ call resend OTP API here (if available)
    _startResendTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        top: true,
        bottom: false,
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
                      'OTP Verification',
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
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter the 6-digit code we sent to',
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
                            widget.email,
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

                    _card(
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
                        text: _verifying ? 'Verifying...' : 'Continue',
                        enabled: _isComplete && !_verifying,
                        onTap: _verify,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFFF0F2F6)),
      ),
      child: child,
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
