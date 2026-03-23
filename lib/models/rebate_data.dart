class Rebate {
  final String rebateId;
  final String userName;
  final String userEmail;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final int totalDays;
  final String? managerNote;
  final DateTime? timestamp;
  final DateTime? updatedAt;

  Rebate({
    this.rebateId = '',
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'Pending',
    required this.totalDays,
    this.managerNote,
    this.timestamp,
    this.updatedAt,
  });
}

class RebateSubmission {
  final String userName;
  final String userEmail;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final int totalDays;

  RebateSubmission({
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.totalDays,
  });
}