class Complaint {
  final String complaintId;
  final String userName;
  final String userEmail;
  final String userId;
  final String complaintText;
  final String category;
  final String status;
  final DateTime? timestamp;
  final DateTime? updatedAt;

  Complaint({
    this.complaintId = '',
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.complaintText,
    required this.category,
    this.status = 'Pending',
    this.timestamp,
    this.updatedAt,
  });
}

class ComplaintSubmission {
  final String userName;
  final String userEmail;
  final String userId;
  final String complaintText;
  final String category;

  ComplaintSubmission({
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.complaintText,
    required this.category,
  });
}