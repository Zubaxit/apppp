/// Runtime health of a source's feed integration.
///
/// This is deliberately separate from [SourceStatus] in the registry: the
/// registry says what we believe about the publication, the health record says
/// what actually happened the last time the app tried to fetch its feed.
class SourceHealth {
  const SourceHealth({
    required this.sourceId,
    this.status = SourceHealthStatus.unknown,
    this.lastCheckedAt,
    this.lastSuccessAt,
    this.lastError,
    this.httpStatus,
    this.itemCount = 0,
    this.latencyMs,
  });

  final String sourceId;
  final SourceHealthStatus status;
  final DateTime? lastCheckedAt;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int? httpStatus;
  final int itemCount;
  final int? latencyMs;

  bool get isOk => status == SourceHealthStatus.ok;
  bool get isFailing => status == SourceHealthStatus.failing;

  SourceHealth copyWith({
    SourceHealthStatus? status,
    DateTime? lastCheckedAt,
    DateTime? lastSuccessAt,
    String? lastError,
    int? httpStatus,
    int? itemCount,
    int? latencyMs,
    bool clearError = false,
  }) {
    return SourceHealth(
      sourceId: sourceId,
      status: status ?? this.status,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      httpStatus: httpStatus ?? this.httpStatus,
      itemCount: itemCount ?? this.itemCount,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  static SourceHealth fromRow(Map<String, Object?> row) {
    int? asInt(Object? value) => value is int ? value : int.tryParse('${value ?? ''}');
    DateTime? asDate(Object? value) {
      final int? millis = asInt(value);
      if (millis == null || millis == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }

    return SourceHealth(
      sourceId: row['source_id'] as String,
      status: SourceHealthStatus.values.firstWhere(
        (SourceHealthStatus s) => s.name == row['status'],
        orElse: () => SourceHealthStatus.unknown,
      ),
      lastCheckedAt: asDate(row['last_checked_at']),
      lastSuccessAt: asDate(row['last_success_at']),
      lastError: row['last_error'] as String?,
      httpStatus: asInt(row['http_status']),
      itemCount: asInt(row['item_count']) ?? 0,
      latencyMs: asInt(row['latency_ms']),
    );
  }

  Map<String, Object?> toRow() => <String, Object?>{
        'source_id': sourceId,
        'status': status.name,
        'last_checked_at': lastCheckedAt?.millisecondsSinceEpoch,
        'last_success_at': lastSuccessAt?.millisecondsSinceEpoch,
        'last_error': lastError,
        'http_status': httpStatus,
        'item_count': itemCount,
        'latency_ms': latencyMs,
      };
}

enum SourceHealthStatus { unknown, ok, failing, disabled }
