/// Модели для API групповой загрузки документов участников.

class GroupDocumentsResponse {
  final Map<String, dynamic> event;
  final List<DocumentInfo> documents;
  final List<UserDocuments> users;
  final String linkBackToEvent;

  GroupDocumentsResponse({
    required this.event,
    required this.documents,
    required this.users,
    required this.linkBackToEvent,
  });

  factory GroupDocumentsResponse.fromJson(Map<String, dynamic> json) {
    return GroupDocumentsResponse(
      event: json['event'] as Map<String, dynamic>? ?? {},
      documents: (json['documents'] as List?)
              ?.map((d) => DocumentInfo.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      users: (json['users'] as List?)
              ?.map((u) => UserDocuments.fromJson(u as Map<String, dynamic>))
              .toList() ??
          [],
      linkBackToEvent: json['link_back_to_event'] as String? ?? '',
    );
  }
}

class DocumentInfo {
  final int index;
  final String name;
  final String? document;
  final String? documentUrl;

  DocumentInfo({
    required this.index,
    required this.name,
    this.document,
    this.documentUrl,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      index: (json['index'] is int) ? json['index'] as int : int.tryParse(json['index']?.toString() ?? '0') ?? 0,
      name: json['name'] as String? ?? '',
      document: json['document'] as String?,
      documentUrl: json['document_url'] as String?,
    );
  }
}

class UserDocuments {
  final int userId;
  final String middlename;
  final Map<String, dynamic>? set;
  final Map<String, dynamic>? participantCategory;
  final List<DocumentStatus> documentsStatus;

  UserDocuments({
    required this.userId,
    required this.middlename,
    this.set,
    this.participantCategory,
    required this.documentsStatus,
  });

  factory UserDocuments.fromJson(Map<String, dynamic> json) {
    return UserDocuments(
      userId: (json['user_id'] is int) ? json['user_id'] as int : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      middlename: json['middlename'] as String? ?? '',
      set: json['set'] as Map<String, dynamic>?,
      participantCategory: json['participant_category'] as Map<String, dynamic>?,
      documentsStatus: (json['documents_status'] as List?)
              ?.map((d) => DocumentStatus.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DocumentStatus {
  final int documentIndex;
  final String name;
  final String? document;
  final String? documentUrl;
  final bool uploaded;
  final String? filePath;

  DocumentStatus({
    required this.documentIndex,
    required this.name,
    this.document,
    this.documentUrl,
    required this.uploaded,
    this.filePath,
  });

  factory DocumentStatus.fromJson(Map<String, dynamic> json) {
    return DocumentStatus(
      documentIndex: (json['document_index'] is int)
          ? json['document_index'] as int
          : int.tryParse(json['document_index']?.toString() ?? '0') ?? 0,
      name: json['name'] as String? ?? '',
      document: json['document'] as String?,
      documentUrl: json['document_url'] as String?,
      uploaded: json['uploaded'] as bool? ?? false,
      filePath: json['file_path'] as String?,
    );
  }
}
