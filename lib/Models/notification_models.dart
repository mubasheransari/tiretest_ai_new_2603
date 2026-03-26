class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime? sentAt;
  final String status;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.sentAt,
    required this.status,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDT(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
    }

    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      sentAt: parseDT(json['sent_at']),
      status: (json['status'] ?? '').toString(),
      createdAt: parseDT(json['created_at']),
    );
  }
}



// class NotificationItem {
//   final String id;
//   final String title;
//   final String body;
//   final DateTime? sentAt;
//   final String status;
//   final DateTime? createdAt;

//   const NotificationItem({
//     required this.id,
//     required this.title,
//     required this.body,
//     required this.sentAt,
//     required this.status,
//     required this.createdAt,
//   });

//   factory NotificationItem.fromJson(Map<String, dynamic> j) {
//     DateTime? _dt(dynamic v) {
//       final s = v?.toString();
//       if (s == null || s.isEmpty) return null;
//       return DateTime.tryParse(s);
//     }

//     return NotificationItem(
//       id: (j['id'] ?? '').toString(),
//       title: (j['title'] ?? '').toString(),
//       body: (j['body'] ?? '').toString(),
//       sentAt: _dt(j['sent_at']),
//       status: (j['status'] ?? '').toString(),
//       createdAt: _dt(j['created_at']),
//     );
//   }
// }

// class NotificationPagination {
//   final int currentPage;
//   final int pageSize;
//   final int total;
//   final int totalPages;
//   final int limit;
//   final int offset;

//   const NotificationPagination({
//     required this.currentPage,
//     required this.pageSize,
//     required this.total,
//     required this.totalPages,
//     required this.limit,
//     required this.offset,
//   });

//   factory NotificationPagination.fromJson(Map<String, dynamic> j) {
//     int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

//     return NotificationPagination(
//       currentPage: _i(j['currentPage']),
//       pageSize: _i(j['pageSize']),
//       total: _i(j['total']),
//       totalPages: _i(j['totalPages']),
//       limit: _i(j['limit']),
//       offset: _i(j['offset']),
//     );
//   }
// }

// class GetNotificationResponse {
//   final String message;
//   final List<NotificationItem> data;
//   final NotificationPagination? pagination;

//   const GetNotificationResponse({
//     required this.message,
//     required this.data,
//     required this.pagination,
//   });

//   factory GetNotificationResponse.fromJson(Map<String, dynamic> j) {
//     final rawList = (j['data'] is List) ? (j['data'] as List) : const [];
//     final items = rawList
//         .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
//         .toList();

//     return GetNotificationResponse(
//       message: (j['message'] ?? '').toString(),
//       data: items,
//       pagination: j['pagination'] == null
//           ? null
//           : NotificationPagination.fromJson(
//               Map<String, dynamic>.from(j['pagination']),
//             ),
//     );
//   }
// }
