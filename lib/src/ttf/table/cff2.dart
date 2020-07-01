
import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/ttf.dart';
import '../cff/dict.dart';
import '../cff/index.dart';
import '../cff/operator.dart';
import '../cff/variations.dart';
import 'abstract.dart';
import 'table_record_entry.dart';

const _kHeaderSize = 5;

class CFF2TableHeader implements BinaryCodable {
  CFF2TableHeader(
    this.majorVersion,
    this.minorVersion,
    this.headerSize,
    this.topDictLength
  );

  factory CFF2TableHeader.fromByteData(ByteData byteData) {
    return CFF2TableHeader(
      byteData.getUint8(0),
      byteData.getUint8(1),
      byteData.getUint8(2),
      byteData.getUint16(3),
    );
  }

  final int majorVersion;
  final int minorVersion;
  final int headerSize;
  final int topDictLength;

  @override
  void encodeToBinary(ByteData byteData) {
    // TODO: implement encodeToBinary
    throw UnimplementedError();
  }

  @override
  int get size => _kHeaderSize;
}

class CFF2Table extends FontTable {
  CFF2Table(
    TableRecordEntry entry,
    this.header,
  ) : super.fromTableRecordEntry(entry);

  factory CFF2Table.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    int offset = entry.offset;

    final header = CFF2TableHeader.fromByteData(byteData.sublistView(offset, _kHeaderSize));
    offset += _kHeaderSize;

    final topDict = CFFDict.fromByteData(byteData.sublistView(offset, header.topDictLength));
    offset += header.topDictLength;

    final globalSubrIndex = CFFIndex.fromByteData(byteData.sublistView(offset));
    offset += globalSubrIndex.size;

    final vstoreEntry = topDict.entryList.firstWhere((e) => e.operator == vstoreOperator, orElse: () => null);
    VariationStoreData vstore;

    if (vstoreEntry != null) {
      final vstoreOffset = vstoreEntry.operandList.first.value as int;
      final vstoreByteData = byteData.sublistView(entry.offset + vstoreOffset);
      vstore = VariationStoreData.fromByteData(vstoreByteData);
    }

    return CFF2Table(entry, header);
  }

  factory CFF2Table.create() {
    return null;
  }

  final CFF2TableHeader header;

  @override
  void encodeToBinary(ByteData byteData) {
  }

  @override
  int get size => throw UnimplementedError();
}