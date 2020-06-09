import 'table_record_entry.dart';

abstract class FontTable {
  FontTable(this.offset, this.length) : entry = null;
  
  FontTable.fromTableRecordEntry(this.entry) 
    : offset = entry.offset, length = entry.length;

  final int offset;
  final int length;
  final TableRecordEntry entry;
}