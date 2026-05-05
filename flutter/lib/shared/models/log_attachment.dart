class LogAttachment {
  final int id;
  final String filePath;
  final String fileType;
  final int fileSize;
  final String? createdAt;

  LogAttachment({
    required this.id,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    this.createdAt,
  });

  factory LogAttachment.fromJson(Map<String, dynamic> json) {
    return LogAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      filePath: (json['file_path'] ?? '').toString(),
      fileType: (json['file_type'] ?? '').toString(),
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}
