import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/theme_provider.dart';

class AccessBadge extends StatelessWidget {
  final String attendeeName;
  final String? attendeePosition;
  final String? attendeeId;
  final String companyName;
  final DateTime date;
  final String startTime;
  final String duration; // 'THREE_HOURS' or 'SIX_HOURS'
  final String bookingId;
  final bool isDark;
  final bool showActions;
  final VoidCallback? onPrintPressed;

  const AccessBadge({
    super.key,
    required this.attendeeName,
    this.attendeePosition,
    this.attendeeId,
    required this.companyName,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.bookingId,
    this.isDark = false,
    this.showActions = true,
    this.onPrintPressed,
  });

  String get endTime {
    if (duration == 'THREE_HOURS') {
      return startTime == '09:00' ? '12:00' : '17:00';
    }
    return '17:00';
  }

  String get badgeData {
    return jsonEncode({
      'id': attendeeId ?? bookingId,
      'name': attendeeName,
      'position': attendeePosition,
      'company': companyName,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'time': startTime,
    });
  }

  void _handleShare(BuildContext context) async {
    final badgeUrl = 'https://paceportsp.com.br/attendee/${attendeeId ?? bookingId}';
    try {
      await Share.share(
        'TCS PacePort Access Ticket\n$attendeeName - $companyName\n$badgeUrl',
        subject: 'TCS PacePort Access Ticket',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  void _handleCopyLink(BuildContext context) async {
    final badgeUrl = 'https://paceportsp.com.br/attendee/${attendeeId ?? bookingId}';
    try {
      await Clipboard.setData(ClipboardData(text: badgeUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error copying link: $e')),
        );
      }
    }
  }

  Future<void> generateAndPrintPDF() async {
    final pdf = pw.Document();

    // Load logo SVG
    final logoSvg = await rootBundle.loadString('assets/logos/tcs-logo-b.svg');

    // Generate QR code data
    final qrCode = pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: badgeData,
      width: 80,
      height: 80,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // Back side (upside down on top)
                pw.Stack(
                  children: [
                    pw.Transform.rotate(
                      angle: 3.14159, // 180 degrees in radians
                      child: _buildPDFBack(logoSvg),
                    ),
                    // Cut lines for back
                    _buildCutLines(),
                  ],
                ),
                // Front side (normal orientation on bottom) - directly attached
                pw.Stack(
                  children: [
                    _buildPDFFront(qrCode, logoSvg),
                    // Cut lines for front
                    _buildCutLines(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Open print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildPDFFront(pw.Widget qrCode, String logoSvg) {
    // Use dark theme colors
    final backgroundColor = isDark ? PdfColors.black : PdfColors.white;
    final borderColor = isDark ? PdfColors.white : PdfColors.black;
    final textColor = isDark ? PdfColors.white : PdfColors.black;
    final secondaryTextColor = isDark ? PdfColors.grey400 : PdfColors.grey700;
    final labelColor = isDark ? PdfColors.grey400 : PdfColors.grey;

    return pw.ClipRRect(
      horizontalRadius: 16,
      verticalRadius: 16,
      child: pw.Container(
        width: 280,
        height: 400,
        decoration: pw.BoxDecoration(
          color: backgroundColor,
          border: pw.Border.all(color: borderColor, width: 3),
        ),
        child: pw.Column(
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                    // Header with Logo and QR
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SvgImage(svg: logoSvg, height: 32),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'ACCESS TICKET',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 2,
                                  color: labelColor,
                                ),
                              ),
                              pw.Text(
                                'PacePort São Paulo',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                            ),
                            child: qrCode,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(height: 2, color: isDark ? PdfColors.grey800 : PdfColors.grey300),
                    pw.SizedBox(height: 16),
                    // Visitor Info
                    pw.Text(
                      'VISITOR',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                        color: labelColor,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      attendeeName,
                      maxLines: 2,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  pw.SizedBox(height: 12),
                  // Position & Company
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'POSITION',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2,
                                color: labelColor,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              attendeePosition ?? 'Visitor',
                              maxLines: 3,
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'COMPANY',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2,
                                color: labelColor,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              companyName,
                              maxLines: 3,
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    pw.SizedBox(height: 12),
                    pw.Container(height: 1, color: isDark ? PdfColors.grey800 : PdfColors.grey300),
                    pw.SizedBox(height: 12),
                    // Visit Details
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPDFInfoBox(
                          'DATE',
                          DateFormat('MMM d').format(date),
                          DateFormat('yyyy').format(date),
                          labelColor,
                          textColor,
                        ),
                        _buildPDFInfoBox(
                          'TIME',
                          startTime,
                          'to $endTime',
                          labelColor,
                          textColor,
                        ),
                        _buildPDFInfoBox(
                          'DURATION',
                          duration == 'THREE_HOURS' ? '3h' : '6h',
                          duration == 'SIX_HOURS' ? 'Full Day' : 'Session',
                          labelColor,
                          textColor,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    // Footer
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '#${bookingId.substring(bookingId.length - 8).toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            color: labelColor,
                          ),
                        ),
                        pw.Text(
                          'AUTHORIZED ACCESS',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                            color: labelColor,
                          ),
                        ),
                      ],
                  ),
                ],
              ),
            ),
          ),
          pw.Container(height: 4, width: double.infinity, color: borderColor),
        ],
      ),
      ),
    );
  }

  pw.Widget _buildPDFBack(String logoSvg) {
    // Use dark theme colors
    final backgroundColor = isDark ? PdfColors.black : PdfColors.white;
    final borderColor = isDark ? PdfColors.white : PdfColors.black;
    final textColor = isDark ? PdfColors.white : PdfColors.black;
    final secondaryTextColor = isDark ? PdfColors.grey400 : PdfColors.grey700;
    final labelColor = isDark ? PdfColors.grey400 : PdfColors.grey;
    final instructionBoxColor = isDark ? PdfColors.grey900 : PdfColors.grey100;

    return pw.ClipRRect(
      horizontalRadius: 16,
      verticalRadius: 16,
      child: pw.Container(
        width: 280,
        height: 400,
        decoration: pw.BoxDecoration(
          color: backgroundColor,
          border: pw.Border.all(color: borderColor, width: 3),
        ),
        child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.SvgImage(svg: logoSvg, height: 40),
          pw.SizedBox(height: 8),
          pw.Text(
            'PacePort São Paulo',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: secondaryTextColor,
            ),
          ),
          pw.SizedBox(height: 32),
          // Instructions
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.ClipRRect(
              horizontalRadius: 12,
              verticalRadius: 12,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: instructionBoxColor,
                ),
                child: pw.Column(
                children: [
                  pw.Text(
                    'VISITOR INSTRUCTIONS',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                      color: labelColor,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  _buildPDFInstructionWithColors('1', 'Present this badge at reception', textColor),
                  pw.SizedBox(height: 12),
                  _buildPDFInstructionWithColors('2', 'Valid for the date and time shown', textColor),
                  pw.SizedBox(height: 12),
                  _buildPDFInstructionWithColors('3', 'Keep badge visible at all times', textColor),
                  pw.SizedBox(height: 12),
                  _buildPDFInstructionWithColors('4', 'Return badge upon departure', textColor),
                ],
              ),
            ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  pw.Widget _buildPDFInfoBox(
    String label,
    String value,
    String subtitle,
    PdfColor labelColor,
    PdfColor valueColor,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5,
            color: labelColor,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: 10,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFInstruction(String number, String text) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 24,
          height: 24,
          decoration: const pw.BoxDecoration(
            color: PdfColors.black,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              number,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 13,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFInstructionWithColors(String number, String text, PdfColor textColor) {
    final circleColor = isDark ? PdfColors.white : PdfColors.black;
    final circleTextColor = isDark ? PdfColors.black : PdfColors.white;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 24,
          height: 24,
          decoration: pw.BoxDecoration(
            color: circleColor,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              number,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: circleTextColor,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCutLines() {
    const double cardWidth = 280;
    const double cardHeight = 400;
    const double lineLength = 10;

    return pw.SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: pw.Stack(
        children: [
          // Top-left corner
          pw.Positioned(
            left: -1,
            top: -1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: lineLength, height: 1, color: PdfColors.grey400),
                pw.Container(width: 1, height: lineLength, color: PdfColors.grey400),
              ],
            ),
          ),
          // Top-right corner
          pw.Positioned(
            right: -1,
            top: -1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(width: lineLength, height: 1, color: PdfColors.grey400),
                pw.Container(width: 1, height: lineLength, color: PdfColors.grey400),
              ],
            ),
          ),
          // Bottom-left corner
          pw.Positioned(
            left: -1,
            bottom: -1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 1, height: lineLength, color: PdfColors.grey400),
                pw.Container(width: lineLength, height: 1, color: PdfColors.grey400),
              ],
            ),
          ),
          // Bottom-right corner
          pw.Positioned(
            right: -1,
            bottom: -1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(width: 1, height: lineLength, color: PdfColors.grey400),
                pw.Container(width: lineLength, height: 1, color: PdfColors.grey400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showPrintPreview(BuildContext context) async {
    _handlePrint(context);
  }

  void _handlePrint(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final dialogDark = themeProvider.isDark;

    // Show both sides of the badge in a dialog for printing
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dialogDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Print Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: dialogDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review both sides before printing',
                          style: TextStyle(
                            fontSize: 12,
                            color: dialogDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: dialogDark ? Colors.white : Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content with both sides
              Container(
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: dialogDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Front side
                      Text(
                        'FRONT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: dialogDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AccessBadge(
                        attendeeName: attendeeName,
                        attendeePosition: attendeePosition,
                        attendeeId: attendeeId,
                        companyName: companyName,
                        date: date,
                        startTime: startTime,
                        duration: duration,
                        bookingId: bookingId,
                        isDark: dialogDark,
                        showActions: false,
                      ),
                      const SizedBox(height: 32),
                      // Divider
                      Container(
                        height: 1,
                        color: dialogDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                      ),
                      const SizedBox(height: 32),
                      // Back side
                      Text(
                        'BACK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: dialogDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBackSide(dialogDark),
                      const SizedBox(height: 24),
                      // Print button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await generateAndPrintPDF();
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dialogDark ? Colors.white : Colors.black,
                            foregroundColor: dialogDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackSide(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 400,
        height: 462,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF09090B), Colors.black, const Color(0xFF09090B)]
                : [Colors.white, const Color(0xFFF9FAFB), Colors.white],
          ),
          border: Border.all(
            color: isDark ? Colors.white : Colors.black,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SvgPicture.asset(
              isDark ? 'assets/logos/tcs-logo-w.svg' : 'assets/logos/tcs-logo-b.svg',
              height: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'PacePort São Paulo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'VISITOR INSTRUCTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInstruction('1', 'Present this badge at reception', isDark),
                    const SizedBox(height: 12),
                    _buildInstruction('2', 'Valid for the date and time shown', isDark),
                    const SizedBox(height: 12),
                    _buildInstruction('3', 'Keep badge visible at all times', isDark),
                    const SizedBox(height: 12),
                    _buildInstruction('4', 'Return badge upon departure', isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Badge Card with integrated bottom stripe
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 400,
            height: 462,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF09090B), Colors.black, const Color(0xFF09090B)]
                    : [Colors.white, const Color(0xFFF9FAFB), Colors.white],
              ),
              border: Border.all(
                color: isDark ? Colors.white : Colors.black,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Corner accents
                Positioned(
                  top: 0,
                  left: 0,
                  child: ClipPath(
                    clipper: _TriangleClipper(isTopLeft: true),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: _TriangleClipper(isTopRight: true),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),

                // Content
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with Logo and QR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Logo and Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset(
                                      isDark ? 'assets/logos/tcs-logo-w.svg' : 'assets/logos/tcs-logo-b.svg',
                                      height: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ACCESS TICKET',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    Text(
                                      'PacePort São Paulo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white : const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: QrImageView(
                                  data: badgeData,
                                  version: QrVersions.auto,
                                  size: 80,
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Divider
                          Container(
                            height: 2,
                            color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                          ),

                          const SizedBox(height: 16),

                          // Visitor Info - Fixed height for 2 lines
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VISITOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 53, // Fixed height for 2 lines (24 * 1.1 * 2)
                                child: Text(
                                  attendeeName,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Position & Company - Fixed height for 3 lines each
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'POSITION',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 50, // Fixed height for 3 lines (14 * 1.2 * 3)
                                      child: Text(
                                        attendeePosition ?? 'Visitor',
                                        maxLines: 3,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COMPANY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 50, // Fixed height for 3 lines (14 * 1.2 * 3)
                                      child: Text(
                                        companyName,
                                        maxLines: 3,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Divider
                          Container(
                            height: 1,
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                          ),

                          const SizedBox(height: 12),

                          // Visit Details
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoBox(
                                  'DATE',
                                  DateFormat('MMM d').format(date),
                                  DateFormat('yyyy').format(date),
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildInfoBox(
                                  'TIME',
                                  startTime,
                                  'to $endTime',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildInfoBox(
                                  'DURATION',
                                  duration == 'THREE_HOURS' ? '3h' : '6h',
                                  duration == 'SIX_HOURS' ? 'Full Day' : 'Session',
                                  isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${bookingId.substring(bookingId.length - 8).toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              Text(
                                'AUTHORIZED ACCESS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bottom stripe integrated inside the card
                    Container(
                      height: 4,
                      width: double.infinity,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (showActions) ...[
          const SizedBox(height: 16),
          // Action Buttons - All in one row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleShare(context),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCopyLink(context),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrintPressed ?? () => _handlePrint(context),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoBox(String label, String value, String subtitle, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  final bool isTopLeft;
  final bool isTopRight;

  _TriangleClipper({this.isTopLeft = false, this.isTopRight = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isTopLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
      path.close();
    } else if (isTopRight) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, 0);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
