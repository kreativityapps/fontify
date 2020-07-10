import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../common/constant.dart';
import '../../utils/enum_class.dart';
import '../../utils/exception.dart';
import '../../utils/otf.dart';
import '../../utils/ucs2.dart';
import '../debugger.dart';

import 'abstract.dart';
import 'table_record_entry.dart';

const _kNameRecordSize = 12;

const _kFormat0 = 0x0;

enum _NameID {
  /// 0:  Copyright notice.
  copyright,

  /// 1:  Font Family name.
  fontFamily,

  /// 2:  Font Subfamily name.
  fontSubfamily,

  /// 3:  Unique font identifier
  uniqueID,

  /// 4:  Full font name
  fullFontName,

  /// 5:  Version string.
  version,

  /// 6:  PostScript name.
  postScriptName,

  /// 8:  Manufacturer Name.
  manufacturer,

  /// 10: Description
  description,

  /// 11: URL of font vendor
  urlVendor,
}

const _kNameIDmap = EnumClass<_NameID, int>({
  _NameID.copyright: 0,
  _NameID.fontFamily: 1,
  _NameID.fontSubfamily: 2,
  _NameID.uniqueID: 3,
  _NameID.fullFontName: 4,
  _NameID.version: 5,
  _NameID.postScriptName: 6,
  _NameID.manufacturer: 8,
  _NameID.description: 10,
  _NameID.urlVendor: 11,
});

/// List of name record templates, sorted by platform and encoding ID
const _kNameRecordTemplateList = [
  /// Macintosh English with Roman encoding
  NameRecord.template(kPlatformMacintosh, 0, 0),

  /// Windows English (US) with UTF-16BE encoding
  NameRecord.template(kPlatformWindows, 1, 0x0409),
];

/// Returns an encoding function for given platform and encoding IDs
/// 
/// NOTE: There are more cases than this, but it will do for now.
List<int> Function(String) _getEncoder(NameRecord record) {
  switch (record.platformID) {
    case kPlatformWindows:
      return toUCS2byteList;
    default:
      return (string) => string.codeUnits;
  }
}

/// Returns a decoding function for given platform and encoding IDs
/// 
/// NOTE: There are more cases than this, but it will do for now.
String Function(List<int>) _getDecoder(NameRecord record) {
  switch (record.platformID) {
    case kPlatformWindows:
      return fromUCS2byteList;
    default:
      return (charCodes) => String.fromCharCodes(charCodes);
  }
}

class NameRecord implements BinaryCodable {
  NameRecord(
    this.platformID,
    this.encodingID,
    this.languageID,
    this.nameID,
    this.length,
    this.offset,
  );

  const NameRecord.template(
    this.platformID,
    this.encodingID,
    this.languageID,
  ) : 
    nameID = null, 
    length = null, 
    offset = null;

  factory NameRecord.fromByteData(ByteData byteData, int offset) {
    final length = byteData.getUint16(offset + 8);
    final stringOffset = byteData.getUint16(offset + 10);

    return NameRecord(
      byteData.getUint16(offset),
      byteData.getUint16(offset + 2),
      byteData.getUint16(offset + 4),
      byteData.getUint16(offset + 6),
      length,
      stringOffset,
    );
  }

  final int platformID;
  final int encodingID;
  final int languageID;
  final int nameID;
  final int length;
  final int offset;

  NameRecord copyWith({
    int platformID,
    int encodingID,
    int languageID,
    int nameID,
    int length,
    int offset,
  }) {
    return NameRecord(
      this.platformID ?? platformID,
      this.encodingID ?? encodingID,
      this.languageID ?? languageID,
      this.nameID ?? nameID,
      this.length ?? length,
      this.offset ?? offset
    );
  }

  @override
  int get size => _kNameRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint16(4, languageID)
      ..setUint16(6, nameID)
      ..setUint16(8, length)
      ..setUint16(10, offset);
  }
}

class NamingTableFormat0Header implements BinaryCodable {
  NamingTableFormat0Header(
    this.format,
    this.count,
    this.stringOffset,
    this.nameRecordList,
  );

  factory NamingTableFormat0Header.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final format = byteData.getUint16(entry.offset);

    if (format != _kFormat0) {
      OTFDebugger.debugUnsupportedTableFormat(entry.tag, format);
      return null;
    }

    final count = byteData.getUint16(entry.offset + 2);
    final stringOffset = byteData.getUint16(entry.offset + 4);
    final nameRecord = List.generate(
      count, 
      (i) => NameRecord.fromByteData(byteData, entry.offset + 6 + i * _kNameRecordSize)
    );

    return NamingTableFormat0Header(format, count, stringOffset, nameRecord);
  }

  factory NamingTableFormat0Header.create(List<NameRecord> nameRecordList) {
    return NamingTableFormat0Header(
      _kFormat0,
      nameRecordList.length,
      6 + nameRecordList.length * _kNameRecordSize,
      nameRecordList
    );
  }

  final int format;
  final int count;
  final int stringOffset;
  final List<NameRecord> nameRecordList;

  @override
  int get size => 6 + nameRecordList.length * _kNameRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, count)
      ..setUint16(4, stringOffset);

    int recordOffset = 6;

    for (final record in nameRecordList) {
      record.encodeToBinary(byteData.sublistView(recordOffset, record.size));
      recordOffset += record.size;
    }
  }
}

abstract class NamingTable extends FontTable {
  NamingTable.fromTableRecordEntry(TableRecordEntry entry) :
    super.fromTableRecordEntry(entry);

  factory NamingTable.fromByteData(ByteData byteData, TableRecordEntry entry) {
    final format = byteData.getUint16(entry.offset);

    switch (format) {
      case _kFormat0:
        return NamingTableFormat0.fromByteData(byteData, entry);
      default:
        OTFDebugger.debugUnsupportedTableFormat(kNameTag, format);
        return null;
    }
  }

  factory NamingTable.create(
    String fontName,
    String description,
    Revision revision, {
      int format = _kFormat0
  }) {
    switch (format) {
      case _kFormat0:
        return NamingTableFormat0.create(fontName, description, revision);
      default:
        OTFDebugger.debugUnsupportedTableFormat(kNameTag, format);
        return null;
    }
  }
}

class NamingTableFormat0 extends NamingTable {
  NamingTableFormat0(
    TableRecordEntry entry,
    this.header,
    this.stringList,
  ) : super.fromTableRecordEntry(entry);

  factory NamingTableFormat0.fromByteData(ByteData byteData, TableRecordEntry entry) {
    final header = NamingTableFormat0Header.fromByteData(byteData, entry);
    final storageAreaOffset = entry.offset + header.size;

    final stringList = [
      for (final record in header.nameRecordList)
        _getDecoder(record)(
          List.generate(
            record.length, 
            (i) => byteData.getUint8(storageAreaOffset + record.offset + i)
          )
        )
    ];
    
    return NamingTableFormat0(entry, header, stringList);
  }

  factory NamingTableFormat0.create(String fontName, String description, Revision revision) {
    if (fontName?.isNotEmpty != true) {
      throw TableDataFormatException('Font name must be not empty');
    }

    final now = DateTime.now();

    /// Values for name ids in sorted order
    final stringForNameMap = {
      _NameID.copyright: '$kVendorName © ${now.year}',
      _NameID.fontFamily: fontName,
      _NameID.fontSubfamily: 'Regular',
      _NameID.uniqueID: fontName,
      _NameID.fullFontName: fontName,
      _NameID.version: 'Version ${revision.major}.${revision.minor}',
      _NameID.postScriptName: fontName.getAsciiPrintable(),
      _NameID.manufacturer: kVendorName,
      _NameID.description: description ?? 'Generated using $kVendorName',
      _NameID.urlVendor: kVendorUrl,
    };

    final stringList = [
      for (int i = 0; i < _kNameRecordTemplateList.length; i++) 
        ...stringForNameMap.values
    ];

    final recordList = <NameRecord>[];

    int stringOffset = 0;

    for (final recordTemplate in _kNameRecordTemplateList) {
      for (final entry in stringForNameMap.entries) {
        final encoder = _getEncoder(recordTemplate);
        final units = encoder(entry.value);

        final record = recordTemplate.copyWith(
          nameID: _kNameIDmap.getValueForKey(entry.key),
          length: units.length,
          offset: stringOffset,
        );

        recordList.add(record);
        stringOffset += units.length;
      }
    }
    
    final header = NamingTableFormat0Header.create(recordList);

    return NamingTableFormat0(null, header, stringList);
  }

  final NamingTableFormat0Header header;
  final List<String> stringList;

  @override
  int get size => 
    header.size + header.nameRecordList.fold<int>(0, (p, r) => p + r.length);

  @override
  void encodeToBinary(ByteData byteData) {
    header.encodeToBinary(byteData.sublistView(0, header.size));

    final storageAreaOffset = header.size;

    for (int i = 0; i < header.nameRecordList.length; i++) {
      final record = header.nameRecordList[i];
      final string = stringList[i];

      int charOffset = storageAreaOffset + record.offset;
      final encoder = _getEncoder(record);
      final units = encoder(string);

      for (final charCode in units) {
        byteData.setUint8(charOffset++, charCode);
      }
    }
  }
}