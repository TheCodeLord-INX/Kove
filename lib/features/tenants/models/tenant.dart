import '../../../core/database/database_constants.dart';

/// Immutable representation of a tenant in the system.
class Tenant {
  final int? id;
  final String name;
  final String roomNumber;
  final String moveInDate;
  final double advancePaid;
  final double initialMeterReading;
  final double monthlyRent;
  final bool activeStatus;

  const Tenant({
    this.id,
    required this.name,
    required this.roomNumber,
    required this.moveInDate,
    this.advancePaid = 0.0,
    this.initialMeterReading = 0.0,
    this.monthlyRent = 0.0,
    this.activeStatus = true,
  });

  /// Deserialize from a SQLite row.
  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map[DbConstants.colId] as int?,
      name: map[DbConstants.colName] as String,
      roomNumber: map[DbConstants.colRoomNumber] as String,
      moveInDate: map[DbConstants.colMoveInDate] as String,
      advancePaid: (map[DbConstants.colAdvancePaid] as num).toDouble(),
      initialMeterReading: (map[DbConstants.colInitialMeterReading] as num?)?.toDouble() ?? 0.0,
      monthlyRent: (map[DbConstants.colMonthlyRent] as num?)?.toDouble() ?? 0.0,
      activeStatus: (map[DbConstants.colActiveStatus] as int) == 1,
    );
  }

  /// Serialize to a SQLite-compatible map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colName: name,
      DbConstants.colRoomNumber: roomNumber,
      DbConstants.colMoveInDate: moveInDate,
      DbConstants.colAdvancePaid: advancePaid,
      DbConstants.colInitialMeterReading: initialMeterReading,
      DbConstants.colMonthlyRent: monthlyRent,
      DbConstants.colActiveStatus: activeStatus ? 1 : 0,
    };
  }

  Tenant copyWith({
    int? id,
    String? name,
    String? roomNumber,
    String? moveInDate,
    double? advancePaid,
    double? initialMeterReading,
    double? monthlyRent,
    bool? activeStatus,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      roomNumber: roomNumber ?? this.roomNumber,
      moveInDate: moveInDate ?? this.moveInDate,
      advancePaid: advancePaid ?? this.advancePaid,
      initialMeterReading: initialMeterReading ?? this.initialMeterReading,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      activeStatus: activeStatus ?? this.activeStatus,
    );
  }

  @override
  String toString() =>
      'Tenant(id: $id, name: $name, room: $roomNumber, active: $activeStatus)';
}
