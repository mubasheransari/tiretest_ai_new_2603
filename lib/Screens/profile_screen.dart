import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Data/token_store.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/Screens/auth_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_bar.dart';
import 'package:ios_tiretest_ai/Widgets/logout_confirm_dialog.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _bg = Color(0xFFF6F7FB);
  static const _title = Color(0xFF111111);
  static const _sub = Color(0xFF7D8790);
  static const _divider = Color(0xFFE9ECF2);

  static const _chipGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.updateProfileStatus != c.updateProfileStatus ||
          p.changePasswordStatus != c.changePasswordStatus,
      listener: (context, state) {
        // ✅ Edit profile toast
        if (state.updateProfileStatus == UpdateProfileStatus.success) {
          final msg = state.updateProfileResponse?.message ??
              "User details updated successfully";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        if (state.updateProfileStatus == UpdateProfileStatus.failure) {
          final msg = state.updateProfileError ?? "Update failed";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }

        // ✅ Change password toast
        if (state.changePasswordStatus == ChangePasswordStatus.success) {
          final msg = state.changePasswordResponse?.message ??
              "Password updated successfully";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        if (state.changePasswordStatus == ChangePasswordStatus.failure) {
          final msg = state.changePasswordError ?? "Change password failed";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        final profile = state.profile;

        final fullName = (profile == null)
            ? '--'
            : '${profile.firstName} ${profile.lastName}'.trim();

        final email = profile?.email ?? '--';
        final phone = profile?.phone ?? '--';
        final avatar = (profile?.profileImage ?? '').toString();

        Widget avatarWidget() {
          if (avatar.isNotEmpty && !avatar.startsWith('http')) {
            final f = File(avatar);
            if (f.existsSync()) return Image.file(f, fit: BoxFit.cover);
          }
          if (avatar.isNotEmpty && avatar.startsWith('http')) {
            return Image.network(avatar, fit: BoxFit.cover);
          }
          return Image.asset('assets/avatar.png', fit: BoxFit.cover);
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
              children: [
                SizedBox(
                  height: 44 * s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Profile',
                      style: TextStyle(
                       fontFamily: 'ClashGrotesk',
                       fontSize: 24 * s,
                       fontWeight: FontWeight.w900,
                       color: Color(0xFF111111))
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14 * s),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 96 * s,
                      height: 96 * s,
                      child: Stack(
                        children: [
                          Container(
                            width: 96 * s,
                            height: 96 * s,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEDEFF3), Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.06),
                                  blurRadius: 16 * s,
                                  offset: Offset(0, 8 * s),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(3 * s),
                              child: ClipOval(child: avatarWidget()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? '--' : fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 20 * s,
                              fontWeight: FontWeight.w700,
                              color: _title,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            email,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w600,
                              color: _sub,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            phone,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w600,
                              color: _sub,
                            ),
                          ),
                          SizedBox(height: 10 * s),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12 * s),
                              onTap: () {
                                _openEditProfileSheet(
                                  context,
                                  s: s,
                                  email: profile?.email ?? "",
                                  firstName: profile?.firstName ?? '',
                                  lastName: profile?.lastName ?? '',
                                  phone: profile?.phone ?? '',
                                  profileImage: profile?.profileImage ?? '',
                                );
                              },
                              child: Container(
                                height: 40 * s,
                                padding: EdgeInsets.symmetric(horizontal: 16 * s),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12 * s),
                                  gradient: _chipGrad,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A7CFF).withOpacity(.20),
                                      blurRadius: 12 * s,
                                      offset: Offset(0, 6 * s),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (state.updateProfileStatus == UpdateProfileStatus.loading) ...[
                                      SizedBox(
                                        width: 16 * s,
                                        height: 16 * s,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10 * s),
                                    ],
                                    Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontFamily: 'ClashGrotesk',
                                        fontSize: 14.5 * s,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18 * s),
                _dividerLine(s),
InkWell(
  onTap: () {
    // ✅ go to tab 2 (reports)
    AppShell.of(context)?.goToTab(BottomTab.about, popToRoot: true);
  },
  child: _menuRow(
    s: s,
    icon: Icons.engineering_outlined,
    label: 'Sponsored vendors',
  ),
),
_dividerLine(s),

                // _menuRow(s: s, icon: Icons.engineering_outlined, label: 'Sponsored vendors'),
                _dividerLine(s),
                InkWell(
                  onTap: () {
    // ✅ go to tab 2 (reports)
    AppShell.of(context)?.goToTab(BottomTab.reports, popToRoot: true);
  },
                  child: _menuRow(s: s, icon: Icons.receipt_long_outlined, label: 'Recent Report')),
                _dividerLine(s),
                InkWell(
                                    onTap: () {
    // ✅ go to tab 2 (reports)
    AppShell.of(context,)?.goToTab(BottomTab.map, popToRoot: true);
  },
                  child: _menuRow(s: s, icon: Icons.add_location_alt_outlined, label: 'Location')),
                _dividerLine(s),

                // ✅ NEW: Change Password row clickable
                InkWell(
                  onTap: () => _openChangePasswordSheet(context, s: s),
                  child: _menuRow(
                    s: s,
                    icon: Icons.password_rounded,
                    label: 'Change Password',
                  ),
                ),
                _dividerLine(s),

                InkWell(
                  onTap: () async {
                    final ok = await LogoutConfirmDialog.show(context);
if (ok) {
await TokenStore().clear();
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
}
                    // await TokenStore().clear();
                    // Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    //   MaterialPageRoute(builder: (_) => const AuthScreen()),
                    //   (route) => false,
                    // );
                  },
                  child: _menuRow(
                    s: s,
                    label: 'Log out',
                    gradientIcon: true,
                  ),
                ),
                _dividerLine(s),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _dividerLine(double s) => Container(height: 1, color: _divider);

  static Widget _menuRow({
    required double s,
    String label = '',
    IconData? icon,
    bool gradientIcon = false,
  }) {
    final leftIcon = gradientIcon
        ? Container(
            width: 24 * s,
            height: 24 * s,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _chipGrad),
            child: Icon(Icons.logout_rounded, size: 14 * s, color: Colors.white),
          )
        : Icon(icon, size: 22 * s, color: _title);

    return SizedBox(
      height: 58 * s,
      child: Row(
        children: [
          leftIcon,
          SizedBox(width: 14 * s),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16 * s,
                fontWeight: FontWeight.w600,
                color: _title,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 22 * s, color: Colors.black.withOpacity(.75)),
        ],
      ),
    );
  }

  // ===========================
  // ✅ Change Password Bottom Sheet (same theme)
  // ===========================
  static void _openChangePasswordSheet(BuildContext context, {required double s}) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final oldCtrl = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;
    bool obscure3 = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final st = context.watch<AuthBloc>().state;
            final loading = st.changePasswordStatus == ChangePasswordStatus.loading;

            const grad = LinearGradient(
              colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            );

            TextStyle labelStyle() => const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                );

            TextStyle inputStyle() => const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                );

            InputDecoration dec(String label, {required bool obscure, required VoidCallback onEyeTap}) {
              return InputDecoration(
                labelText: label,
                labelStyle: labelStyle(),
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6B7280)),
                suffixIcon: IconButton(
                  onPressed: onEyeTap,
                  icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  color: const Color(0xFF6B7280),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Change Password",
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                   const SizedBox(height: 14),
                   TextField(
                    controller: oldCtrl,
                    obscureText: obscure3,
                    style: inputStyle(),
                    decoration: dec(
                      "Old Password",
                      obscure: obscure3,
                      onEyeTap: () => setSheetState(() => obscure3 = !obscure3),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: newCtrl,
                    obscureText: obscure1,
                    style: inputStyle(),
                    decoration: dec(
                      "New Password",
                      obscure: obscure1,
                      onEyeTap: () => setSheetState(() => obscure1 = !obscure1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure2,
                    style: inputStyle(),
                    decoration: dec(
                      "Confirm New Password",
                      obscure: obscure2,
                      onEyeTap: () => setSheetState(() => obscure2 = !obscure2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: 170,
                    height: 45,
                    child: _PrimaryGradientButton(
                      text: "Update",
                      loading: loading,
                      onPressed: loading
                          ? null
                          : () {
                              final a = newCtrl.text.trim();
                              final b = confirmCtrl.text.trim();
                              final oldPassword = oldCtrl.text.trim();

                              if (a.isEmpty || b.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please fill both password fields")),
                                );
                                return;
                              }
                              if (a != b) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("New passwords do not match")),
                                );
                                return;
                              }

                              context.read<AuthBloc>().add(
                                    ChangePasswordRequested(
                                      oldPassword: oldPassword,
                                      newPassword: a,
                                      confirmNewPassword: b,
                                    ),
                                  );

                              Navigator.pop(context);
                            },
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }


  static void _openEditProfileSheet(
    BuildContext context, {
    required double s,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String profileImage,
  }) {
        final emailCtrl = TextEditingController(text: email);

    final fnCtrl = TextEditingController(text: firstName);
    final lnCtrl = TextEditingController(text: lastName);
    final phoneCtrl = TextEditingController(text: phone);


    String pickedImagePath = profileImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final state = context.watch<AuthBloc>().state;
            final loading = state.updateProfileStatus == UpdateProfileStatus.loading;

            const grad = LinearGradient(
              colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            );

            TextStyle labelStyle() => const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                );

            TextStyle inputStyle() => const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                );

            InputDecoration dec(String label, IconData icon) {
              return InputDecoration(
                labelText: label,
                labelStyle: labelStyle(),
                prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              );
            }

            Widget avatarPreview() {
              if (pickedImagePath.isNotEmpty && !pickedImagePath.startsWith('http')) {
                final f = File(pickedImagePath);
                if (f.existsSync()) return Image.file(f, fit: BoxFit.cover);
              }
              if (pickedImagePath.isNotEmpty && pickedImagePath.startsWith('http')) {
                return Image.network(pickedImagePath, fit: BoxFit.cover);
              }
              return Image.asset('assets/avatar.png', fit: BoxFit.cover);
            }

            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final xfile = await picker.pickImage(source: source, imageQuality: 80);
                if (xfile == null) return;
                setSheetState(() => pickedImagePath = xfile.path);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to pick image: $e', style: const TextStyle(fontFamily: 'ClashGrotesk'))),
                );
              }
            }

            void openPickChooser() {
              if (loading) return;

              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Choose Photo",
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text(
                              "Upload from Gallery",
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await pickImage(ImageSource.gallery);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_camera_outlined),
                            title: const Text(
                              "Take a Photo",
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await pickImage(ImageSource.camera);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: openPickChooser,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: grad),
                            child: ClipOval(
                              child: Container(
                                color: const Color(0xFFF3F4F6),
                                child: avatarPreview(),
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: grad),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                    TextField(
                    controller: emailCtrl,
                    style: inputStyle(),
                    keyboardType: TextInputType.phone,
                    decoration: dec("Email", Icons.phone_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: fnCtrl, style: inputStyle(), decoration: dec("First Name", Icons.person_outline)),
                  const SizedBox(height: 10),
                  TextField(controller: lnCtrl, style: inputStyle(), decoration: dec("Last Name", Icons.person_outline)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    style: inputStyle(),
                    keyboardType: TextInputType.phone,
                    decoration: dec("Phone", Icons.phone_outlined),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 155,
                    height: 45,
                    child: _PrimaryGradientButton(
                      text: "Save Changes",
                      loading: loading,
                      onPressed: loading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                    UpdateUserDetailsRequested(
                                      email: emailCtrl.text,
                                      firstName: fnCtrl.text,
                                      lastName: lnCtrl.text,
                                      phone: phoneCtrl.text,
                                      profileImage: pickedImagePath,
                                    ),
                                  );
                              Navigator.pop(context);
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.8 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _grad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}


