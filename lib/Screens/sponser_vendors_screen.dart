import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:url_launcher/url_launcher.dart';


Future<void> _makePhoneCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    debugPrint('❌ Could not launch dialer');
  }
}

Future<void> _sendSms(String phone) async {
  final uri = Uri(scheme: 'sms', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    debugPrint('❌ Could not launch SMS');
  }
}

class SponsoredVendorsScreen extends StatelessWidget {
  const SponsoredVendorsScreen({super.key});

  static const _bg = Color(0xFFF6F7FB);
  static const _title = Color(0xFF111111);
  static const _text = Color(0xFF7D8790);
  static const _closed = Color(0xFFE53935);
  static const _cardBorder = Color(0xFFE9ECF2);
  static const _star = Color(0xFFFFC107);
  static const _dark = Color(0xFF1F1F1F);

  static const _chipGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _circleGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (p, c) =>
              p.shopsStatus != c.shopsStatus ||
              p.shops != c.shops ||
              p.shopsError != c.shopsError,
          builder: (context, state) {
            final sponsored = state.shops.where((x) => x.isSponsored).toList();

            sponsored.sort((a, b) {
              final r = b.rating.compareTo(a.rating);
              if (r != 0) return r;
              return b.navigationCount.compareTo(a.navigationCount);
            });

            return ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 3 * s, 16 * s, 24 * s),
              children: [
                SizedBox(
                  height: 44 * s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Sponsored Vendors List',
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w900,
                          color: _title,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * s),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _StatTile(
                      s: 1, // overwritten below by SizedBox width anyway, keep as-is in your project
                      number: '1,250+',
                      line1: 'Trusted',
                      line2: 'Vendors',
                    ),
                    _StatTile(
                      s: 1,
                      number: '15k+',
                      line1: 'Happy',
                      line2: 'Customers',
                    ),
                    _StatTile(
                      s: 1,
                      number: '50+',
                      line1: 'Service',
                      line2: 'Coverage',
                    ),
                  ],
                ),

                SizedBox(height: 14 * s),

                if (state.shopsStatus == ShopsStatus.loading) ...[
                  SizedBox(height: 18 * s),
                  const Center(child: CircularProgressIndicator()),
                ] else if (state.shopsStatus == ShopsStatus.failure) ...[
                  SizedBox(height: 18 * s),
                  _ErrorBox(
                    s: s,
                    message: state.shopsError ?? "Failed to load shops",
                  ),
                ] else if (sponsored.isEmpty) ...[
                  SizedBox(height: 18 * s),
                  _EmptyBox(
                    s: s,
                    message: "No sponsored vendors found.",
                  ),
                ] else ...[
                  ...sponsored.map((v) => _VendorCard(scale: s, vendor: v)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================== Stat Tile ==================

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.s,
    required this.number,
    required this.line1,
    required this.line2,
  });

  final double s;
  final String number;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width / 390.0;
    return SizedBox(
      width: 118 * scale,
      child: Column(
        children: [
          Container(
            width: 88 * scale,
            height: 88 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SponsoredVendorsScreen._circleGrad,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A7CFF).withOpacity(.28),
                  blurRadius: 18 * scale,
                  offset: Offset(0, 10 * scale),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.white,
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 9 * scale),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F8FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12 * scale,
                  offset: Offset(0, 8 * scale),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  line1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12.5 * scale,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
                Text(
                  line2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12.5 * scale,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.scale, required this.vendor});

  final double scale;
  final ShopVendorModel vendor;

  static const _cardBorder = SponsoredVendorsScreen._cardBorder;
  static const _text = SponsoredVendorsScreen._text;
  static const _title = SponsoredVendorsScreen._title;
  static const _chipGrad = SponsoredVendorsScreen._chipGrad;
  static const _closed = SponsoredVendorsScreen._closed;
  static const _dark = SponsoredVendorsScreen._dark;

  static const String kSponsoredBannerImg =
      "https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg";

  @override
  Widget build(BuildContext context) {
    final s = scale;

    final subtitle = (vendor.services ?? '').trim().isNotEmpty
        ? (vendor.services ?? '').trim()
        : (vendor.tyreBrand ?? '').trim().isNotEmpty
            ? (vendor.tyreBrand ?? '').trim()
            : '—';

    final promoText = (vendor.promocode?.promocode ?? '').trim();

    // ✅ increase image box size here
    final double imgW = 150 * s;
    final double imgH = 110 * s;

    return Container(
      margin: EdgeInsets.only(bottom: 9 * s),
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: _cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16 * s,
            offset: Offset(0, 8 * s),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Bigger image + Sponsored overlay
          SizedBox(
            width: imgW,
            height: imgH,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12 * s),
                  child: Image.network(
                    kSponsoredBannerImg,
                    width: imgW,
                    height: imgH, // ✅ match the box height
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImg(s, imgW, imgH),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _placeholderImg(s, imgW, imgH);
                    },
                  ),
                ),

                Positioned(
                  left: 6 * s,
                  top: 6 * s,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * s,
                      vertical: 4 * s,
                    ),
                    decoration: BoxDecoration(
                      gradient: _chipGrad,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A7CFF).withOpacity(.24),
                          blurRadius: 8 * s,
                          offset: Offset(0, 3 * s),
                        ),
                      ],
                    ),
                    child: Text(
                      'Sponsored',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 10.5 * s,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12 * s),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          vendor.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 16.5 * s,
                            fontWeight: FontWeight.w800,
                            color: _title,
                          ),
                        ),
                      ),
                  _gradAction(
  s,
  Icons.call_rounded,
  onTap: () => _makePhoneCall(vendor.phoneNumber.toString()),
),

SizedBox(width: 6 * s),

_gradAction(
  s,
  Icons.chat_rounded,
  onTap: () => _sendSms(vendor.phoneNumber.toString()),
),
                    ],
                  ),
                  SizedBox(height: 4 * s),

                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 4 * s),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Closed ',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _closed,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '– ',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _dark,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Opens 08:00',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _dark,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (promoText.isNotEmpty) ...[
                    SizedBox(height: 6 * s),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * s,
                            vertical: 4 * s,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Code: $promoText',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 11.5 * s,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (vendor.discountPercentage > 0)
                          Text(
                            '${vendor.discountPercentage.toStringAsFixed(0)}% OFF',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 11.5 * s,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF6A7CFF),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(height: 6 * s),
                  ],

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10 * s,
                        backgroundColor: const Color(0xFFEFF3FF),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 14 * s,
                          color: const Color(0xFF6A7CFF),
                        ),
                      ),
                      SizedBox(width: 6 * s),
                      Expanded(
                        child: Text(
                          vendor.displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 12.5 * s,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF808A93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _gradAction(
  double s,
  IconData icon, {
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 32 * s,
      height: 32 * s,
      margin: EdgeInsets.only(left: 6 * s),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _chipGrad,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A7CFF).withOpacity(.24),
            blurRadius: 8 * s,
            offset: Offset(0, 3 * s),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16 * s),
    ),
  );
}

  Widget _placeholderImg(double s, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * s),
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF3FF), Color(0xFFF7F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 28 * s,
          color: const Color(0xFF6A7CFF),
        ),
      ),
    );
  }
}


class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.s, required this.message});
  final double s;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFE9ECF2)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'ClashGrotesk',
          fontSize: 13 * s,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6A6F7B),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.s, required this.message});
  final double s;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFFFD7D7)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'ClashGrotesk',
          fontSize: 13 * s,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE53935),
        ),
      ),
    );
  }
}
