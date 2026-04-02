// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchRecordAdapter extends TypeAdapter<MatchRecord> {
  @override
  final int typeId = 0;

  @override
  MatchRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchRecord(
      date: fields[0] as DateTime,
      machine: fields[1] as String,
      wins: fields[2] as int,
      losses: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MatchRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.machine)
      ..writeByte(2)
      ..write(obj.wins)
      ..writeByte(3)
      ..write(obj.losses);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
