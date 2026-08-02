import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/attendance.dart';

class ExportService {
  Future<String> exportAttendanceToExcel({
    required String subject,
    required List<AttendanceRecord> records,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];
    excel.delete('Sheet1');

    final headers = ['Roll Number', 'Student Name', 'Marked At', 'Face Verified'];

    // --- Row 0: Title (appended first, so it's guaranteed to be row 0) ---
    sheet.appendRow([TextCellValue('Attendance Report — $subject')]);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: 0),
    );
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );

    // --- Row 1: Header ---
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blue800,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
      cell.cellStyle = headerStyle;
    }

    // --- Rows 2+: Data ---
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (final record in records) {
      final rowValues = [
        record.rollNumber ?? 'N/A',
        record.studentName,
        _formatDateTime(record.markedAt),
        record.faceVerified ? 'Yes' : 'No',
      ];
      sheet.appendRow(rowValues.map((v) => TextCellValue(v)).toList());

      final rowIndex = sheet.maxRows - 1; // the row we just appended
      for (int col = 0; col < rowValues.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.cellStyle = dataStyle;
      }
    }

    // --- Column widths ---
    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 14);

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final safeSubject = subject.replaceAll(RegExp(r'[^\w\s-]'), '');
    final filePath = '${directory.path}/attendance_${safeSubject}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return filePath;
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Future<void> shareFile(String filePath, String subject) async {
    if (Platform.isWindows) {
      final directory = File(filePath).parent.path;
      await Process.run('explorer.exe', [directory]);
    } else {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Attendance report for $subject',
      );
    }
  }
}