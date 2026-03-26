import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/two_wheeler_scanner_screen.dart';



const kBg = Color(0xFFF6F7FA);

class VehicleFormPreferencesBikeScreen extends StatefulWidget {
  const VehicleFormPreferencesBikeScreen({super.key});

  @override
  State<VehicleFormPreferencesBikeScreen> createState() =>
      _VehicleFormPreferencesBikeScreenState();
}

class _VehicleFormPreferencesBikeScreenState
    extends State<VehicleFormPreferencesBikeScreen> {
  final _formKey = GlobalKey<FormState>();

  final String _vehiclePreference = 'Bike';

  final _brandCtrl = TextEditingController(text: 'Yamaha');
  final _modelCtrl = TextEditingController(text: 'R15');
  final _plateCtrl = TextEditingController(text: '8383092');
  final _tireBrandCtrl = TextEditingController(text: 'YOKOHAMA');
  final _tireDimensionCtrl = TextEditingController(text: '17');

  final box = GetStorage();

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _tireBrandCtrl.dispose();
    _tireDimensionCtrl.dispose();
    super.dispose();
  }

  // ✅ identical style to 4-wheeler: keep "token" first
  String? _readToken() {
    final t = box.read("token");
    if (t == null) return null;
    final s = t.toString().trim();
    return s.isEmpty ? null : s;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
          AddVehiclePreferenccesEvent(
            vehiclePreference: _vehiclePreference,
            brandName: _brandCtrl.text.trim(),
            modelName: _modelCtrl.text.trim(),
            licensePlate: _plateCtrl.text.trim(),
            isOwn: null,
            tireBrand: _tireBrandCtrl.text.trim(),
            tireDimension: _tireDimensionCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tok = _readToken();
    final size = MediaQuery.sizeOf(context);
    const baseW = 393.0;
    final s = size.width / baseW;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.addVehiclePreferencesStatus != curr.addVehiclePreferencesStatus,
      listener: (context, state) {
        if (state.addVehiclePreferencesStatus ==
            AddVehiclePreferencesStatus.success) {
          if (tok == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing token. Please login again.')),
            );
            return;
          }

          final profile = state.profile;
          final pref = state.vehiclePreferencesModel;

          final userId = profile?.userId;
          final vehicleIds = pref?.vehicleIds;

          if (userId == null || userId.toString().trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing userId. Please login again.')),
            );
            return;
          }

          if (vehicleIds == null || vehicleIds.toString().trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing vehicleId from server.')),
            );
            return;
          }

final stored = pref!.storedData.first;

// NOTE: replace these names with your actual response keys
final frontTyreId = stored.frontTyreId.toString();
final backTyreId  = stored.backTyreId.toString();

Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(
    builder: (_) => TwoWheelerGenerateReportScreen( // <-- your camera screen
      title: "Bike Tyre Scanner",
      userId: userId.toString(),
      vehicleId: vehicleIds.toString(),
      token: tok,
      vin: 'kjbjk',
      vehicleType: "bike",
      frontTyreId: frontTyreId,
      backTyreId: backTyreId, 
    ),
  ),
);

        }

        if (state.addVehiclePreferencesStatus ==
            AddVehiclePreferencesStatus.failure) {
          final msg =
              state.errorMessageVehiclePreferences ?? 'Failed to save vehicle';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 24 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 6 * s),
                _HeaderTitle(s: s),
                SizedBox(height: 18 * s),
                _VehicleCard(
                  s: s,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _BikeBadge(s: s),
                        SizedBox(height: 18 * s),
                        _TextFieldRow(
                          s: s,
                          label: 'Brand name',
                          hint: 'e.g. Yamaha',
                          controller: _brandCtrl,
                        ),
                        SizedBox(height: 14 * s),
                        _TextFieldRow(
                          s: s,
                          label: 'Model name',
                          hint: 'e.g. R15',
                          controller: _modelCtrl,
                        ),
                        SizedBox(height: 14 * s),
                        _TextFieldRow(
                          s: s,
                          label: 'License plate',
                          hint: 'e.g. 8383092',
                          controller: _plateCtrl,
                        ),
                        SizedBox(height: 18 * s),
                        _TextFieldRow(
                          s: s,
                          label: 'Tire brand',
                          hint: 'e.g. YOKOHAMA',
                          controller: _tireBrandCtrl,
                        ),
                        SizedBox(height: 14 * s),
                        _TextFieldRow(
                          s: s,
                          label: 'Tire dimension',
                          hint: 'e.g. 17',
                          controller: _tireDimensionCtrl,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 22 * s),
                        BlocBuilder<AuthBloc, AuthState>(
                          buildWhen: (p, c) =>
                              p.addVehiclePreferencesStatus !=
                              c.addVehiclePreferencesStatus,
                          builder: (context, state) {
                            final loading =
                                state.addVehiclePreferencesStatus ==
                                    AddVehiclePreferencesStatus.loading;
                            return _PrimaryButton(
                              s: s,
                              label: loading ? 'Saving…' : 'Save Bike',
                              onTap: loading ? null : _submit,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== SAME TEXT STYLE AS CAR SCREEN ===================== */

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2 * s),
          child: _BackButtonPill(s: s),
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13 * s,
                color: const Color(0xFF6A6F7B),
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: 'Vehicle Preference\n',
                  style: TextStyle(
                    fontSize: 24 * s,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                TextSpan(
                  text: 'Add your vehicle details',
                  style: TextStyle(
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A6F7B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButtonPill extends StatelessWidget {
  const _BackButtonPill({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canPop ? () => Navigator.of(context).pop() : null,
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

class _BikeBadge extends StatelessWidget {
  const _BikeBadge({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42 * s,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: EdgeInsets.all(4 * s),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pedal_bike_rounded, size: 22 * s, color: Colors.white),
            SizedBox(width: 6 * s),
            Text(
              "Bike",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 18 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.s, required this.child});
  final double s;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.s,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });

  final double s;
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 13 * s,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: 6 * s),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F5),
            borderRadius: BorderRadius.circular(12 * s),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14 * s,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: 13 * s,
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.s,
    required this.label,
    required this.onTap,
  });

  final double s;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * s),
          gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 14 * s,
              offset: Offset(0, 8 * s),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 15 * s,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
