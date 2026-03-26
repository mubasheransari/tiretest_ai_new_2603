import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/notification_models.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _kNotifReadIds = "notif_read_ids";

  Set<String> _readIds() {
    final box = GetStorage();
    final raw = box.read(_kNotifReadIds);
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    return <String>{};
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt;
    String two(int n) => n.toString().padLeft(2, '0');
    return "${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;
    context.read<AuthBloc>().add(
      const NotificationFetchRequested(page: 1, limit: 50, silent: true),
    );

    return Scaffold(
      backgroundColor: Color(0xFFF6F7FB),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 65.0),
            child: SizedBox(
              height: 34 * s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left back button
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios),
                      ),
                    ),
                  ),

                  // Center title (dynamic text)
                  Center(
                    child: Text(
                      'Notifications', // <- replace with your dynamic value
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 24 * s,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 7 * s),
          BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (p, c) =>
                p.notifications != c.notifications ||
                p.notificationUnreadCount != c.notificationUnreadCount ||
                p.notificationError != c.notificationError,
            builder: (context, state) {
              final list = state.notifications;
              final readIds = _readIds();

              if ((state.notificationError ?? '').isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      state.notificationError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'ClashGrotesk'),
                    ),
                  ),
                );
              }

              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    "No notifications yet.",
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = list[i];
                  final isRead = readIds.contains(n.id);

                  final dt = n.sentAt ?? n.createdAt;
                  final subtitle = _fmtDate(dt);

                  return _NotificationTile(
                    item: n,
                    isRead: isRead,
                    subtitle: subtitle,
                    onTap: () {
                      // ✅ mark read locally -> decreases counter
                      context.read<AuthBloc>().add(
                        NotificationMarkSeenByIds([n.id]),
                      );

                      // ✅ show details bottom sheet (optional)
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        builder: (_) => _NotificationDetails(item: n),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isRead,
    required this.subtitle,
    required this.onTap,
  });

  final NotificationItem item;
  final bool isRead;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFE9E9EF)
                  : const Color(0xFF7F53FD).withOpacity(.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // left dot
              Container(
                margin: const EdgeInsets.only(top: 6),
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF7F53FD),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                        fontSize: 16,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                size: 22,
                color: isRead
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF7F53FD),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDetails extends StatelessWidget {
  const _NotificationDetails({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            width: 44,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            item.title,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.body,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: Color(0xFF374151),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Close",
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
