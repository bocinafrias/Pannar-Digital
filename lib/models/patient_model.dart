import 'dart:convert';

class PatientModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final Map<String, dynamic>? clinicalData;
  final int totalSessions;
  final String? psychologistId; // ID del psicólogo que creó este paciente
  final DateTime createdAt;
  final DateTime? updatedAt;

  PatientModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.clinicalData,
    this.totalSessions = 0,
    this.psychologistId,
    required this.createdAt,
    this.updatedAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      clinicalData: json['clinical_data'] != null
          ? (json['clinical_data'] is String
              // SQLite almacena clinical_data como JSON string
              ? Map<String, dynamic>.from(
                  _decodeClinicalData(json['clinical_data'] as String))
              // Supabase devuelve clinical_data como Map (JSONB)
              : Map<String, dynamic>.from(json['clinical_data'] as Map))
          : null,
      totalSessions: (json['total_sessions'] as int?) ?? 0,
      psychologistId: json['psychologist_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'address': address,
      'clinical_data': clinicalData,
      'total_sessions': totalSessions,
      'psychologist_id': psychologistId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _decodeClinicalData(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  PatientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    Map<String, dynamic>? clinicalData,
    int? totalSessions,
    String? psychologistId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      clinicalData: clinicalData ?? this.clinicalData,
      totalSessions: totalSessions ?? this.totalSessions,
      psychologistId: psychologistId ?? this.psychologistId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
