import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shift_record_model.dart';
import 'database_service.dart';

class ImportExportService {
  ImportExportService._();

  static final ImportExportService instance = ImportExportService._();

  /// Exports all records to an Excel file and shares it
  Future<void> exportToExcel() async {
    final records = await DatabaseService.instance.getRecentRecords(limit: 99999);

    final excel = Excel.createExcel();
    final sheet = excel['History'];
    excel.setDefaultSheet('History');
    
    // Remove default Sheet1
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Add Headers
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Punch In (ISO)'),
      TextCellValue('Punch Out (ISO)'),
      TextCellValue('Total Break (Seconds)'),
      TextCellValue('Scheduled Duration (Minutes)'),
      TextCellValue('Profile ID'),
      TextCellValue('Profile Name'),
    ]);

    // Add Data
    for (final r in records) {
      sheet.appendRow([
        IntCellValue(r.id ?? 0),
        TextCellValue(r.date),
        TextCellValue(r.punchIn),
        TextCellValue(r.punchOut ?? ''),
        IntCellValue(r.totalBreakSeconds),
        IntCellValue(r.scheduledDurationMinutes),
        TextCellValue(r.profileId),
        TextCellValue(r.profileName),
      ]);
    }

    // Save and share
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shift_history.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Shift History Export');
    }
  }

  /// Prompts user to pick an Excel file, reads it, and inserts valid records
  Future<int> importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) {
      return 0; // Cancelled or failed
    }

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    
    int importedCount = 0;

    for (final table in excel.tables.keys) {
      final rows = excel.tables[table]?.rows ?? [];
      if (rows.isEmpty) continue;

      // Skip header row
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 8) continue; // Ensure all columns are present

        try {
          final date = _getString(row[1]?.value);
          final punchIn = _getString(row[2]?.value);
          final punchOutStr = _getString(row[3]?.value);
          final punchOut = punchOutStr.isEmpty ? null : punchOutStr;
          final breakSeconds = _getInt(row[4]?.value);
          final scheduledMinutes = _getInt(row[5]?.value);
          final profileId = _getString(row[6]?.value);
          final profileName = _getString(row[7]?.value);

          if (date.isNotEmpty && punchIn.isNotEmpty) {
            final record = ShiftRecordModel(
              date: date,
              punchIn: punchIn,
              punchOut: punchOut,
              totalBreakSeconds: breakSeconds,
              scheduledDurationMinutes: scheduledMinutes,
              profileId: profileId.isNotEmpty ? profileId : 'DEFAULT',
              profileName: profileName.isNotEmpty ? profileName : 'Imported',
            );
            await DatabaseService.instance.insertRecord(record);
            importedCount++;
          }
        } catch (e) {
          // Skip invalid rows silently
        }
      }
    }

    return importedCount;
  }

  String _getString(CellValue? cell) {
    if (cell == null) return '';
    if (cell is TextCellValue) return cell.value.text ?? '';
    if (cell is IntCellValue) return cell.value.toString();
    if (cell is DoubleCellValue) return cell.value.toString();
    if (cell is DateCellValue) {
      return '${cell.year}-${cell.month.toString().padLeft(2, '0')}-${cell.day.toString().padLeft(2, '0')}';
    }
    return cell.toString();
  }

  int _getInt(CellValue? cell) {
    if (cell == null) return 0;
    if (cell is IntCellValue) return cell.value;
    if (cell is DoubleCellValue) return cell.value.toInt();
    if (cell is TextCellValue) return int.tryParse(cell.value.text ?? '') ?? 0;
    return 0;
  }
}
