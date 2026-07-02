import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ============================================================
// SERVICE EXPORT PDF — Carnet de Santé Animal
// ✅ Police Google Fonts (support Unicode complet : é à ê — etc.)
// ✅ Pas de TooManyPagesException
// ============================================================
class CarnetSantePdfService {

  static const _vert      = PdfColor.fromInt(0xFF2E7D32);
  static const _vertClair = PdfColor.fromInt(0xFFE8F5E9);
  static const _bleu      = PdfColor.fromInt(0xFF1565C0);
  static const _bleuClair = PdfColor.fromInt(0xFFE3F2FD);
  static const _gris      = PdfColor.fromInt(0xFF757575);
  static const _grisClair = PdfColor.fromInt(0xFFF5F5F5);
  static const _orange    = PdfColor.fromInt(0xFFE65100);
  static const _orangeClair = PdfColor.fromInt(0xFFFFF3E0);
  static const _noir      = PdfColor.fromInt(0xFF212121);

  // ─── Générer et partager ───────────────────────────────────
  static Future<void> genererEtPartager({
    required BuildContext           context,
    required Map<String, dynamic>   animal,
    required List<Map<String, dynamic>> consultations,
    required List<Map<String, dynamic>> vaccinations,
    required String                 nomEleveur,
  }) async {
    try {
      // ✅ Charger une police Google Fonts avec support Unicode
      final fontRegular = await PdfGoogleFonts.nunitoRegular();
      final fontBold    = await PdfGoogleFonts.nunitoBold();
      final fontItalic  = await PdfGoogleFonts.nunitoItalic();

      final pdf = await _genererPdf(
        animal        : animal,
        consultations : consultations,
        vaccinations  : vaccinations,
        nomEleveur    : nomEleveur,
        fontRegular   : fontRegular,
        fontBold      : fontBold,
        fontItalic    : fontItalic,
      );

      final nomAnimal  = animal['animal_nom']?.toString() ?? 'animal';
      final nomFichier =
          'carnet_sante_${nomAnimal}_'
          '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      await Printing.sharePdf(
        bytes   : await pdf.save(),
        filename: nomFichier,
      );
    } catch (e) {
      debugPrint('Erreur génération PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content        : Text('Erreur PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Document PDF ──────────────────────────────────────────
  static Future<pw.Document> _genererPdf({
    required Map<String, dynamic>       animal,
    required List<Map<String, dynamic>> consultations,
    required List<Map<String, dynamic>> vaccinations,
    required String                     nomEleveur,
    required pw.Font                    fontRegular,
    required pw.Font                    fontBold,
    required pw.Font                    fontItalic,
  }) async {
    final pdf      = pw.Document();
    final dateGen  = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final nomAnimal  = animal['animal_nom']?.toString()  ?? 'Inconnu';
    final raceAnimal = animal['animal_race']?.toString() ?? 'N/A';
    final origine    = animal['source']?.toString() == 'nee'
        ? 'Nouveau-ne'
        : 'Achete';

    // Style de base avec la police Unicode
    final styleBase = pw.TextStyle(font: fontRegular, fontSize: 10, color: _noir);
    final styleBold = pw.TextStyle(font: fontBold,    fontSize: 10, color: _noir);
    final styleGris = pw.TextStyle(font: fontRegular, fontSize: 9,  color: _gris);
    final styleItalique = pw.TextStyle(font: fontItalic, fontSize: 10, color: _gris);

    pdf.addPage(
      pw.MultiPage(
        pageFormat : PdfPageFormat.a4,
        margin     : const pw.EdgeInsets.all(30),
        // ✅ Police par défaut pour toute la page
        theme      : pw.ThemeData.withFont(
          base  : fontRegular,
          bold  : fontBold,
          italic: fontItalic,
        ),
        header: (ctx) => _header(nomAnimal, dateGen, fontBold, fontRegular),
        footer: (ctx) => _footer(ctx, fontRegular),
        build : (ctx) => [

          // ── Infos animal ────────────────────────────────
          _titreSection('Informations Generales', _vert, fontBold),
          pw.SizedBox(height: 6),
          pw.Container(
            padding   : const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color       : _vertClair,
              borderRadius: pw.BorderRadius.circular(6),
              border      : pw.Border.all(color: _vert, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Row(children: [
                  pw.Expanded(child: _infoLigne('Nom'     , nomAnimal,  fontBold, fontRegular)),
                  pw.Expanded(child: _infoLigne('Race'    , raceAnimal, fontBold, fontRegular)),
                ]),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  pw.Expanded(child: _infoLigne('Origine' , origine,    fontBold, fontRegular)),
                  pw.Expanded(child: _infoLigne('Eleveur' , nomEleveur, fontBold, fontRegular)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Resume ──────────────────────────────────────
          pw.Row(children: [
            pw.Expanded(child: _statBox('${consultations.length}', 'Consultations', _vert,  _vertClair,  fontBold, fontRegular)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _statBox('${vaccinations.length}',  'Vaccinations',  _bleu,  _bleuClair,  fontBold, fontRegular)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _statBox(
              '${consultations.length + vaccinations.length}',
              'Total actes', _orange, _orangeClair, fontBold, fontRegular)),
          ]),
          pw.SizedBox(height: 18),

          // ── Consultations ────────────────────────────────
          _titreSection('Historique des Consultations', _vert, fontBold),
          pw.SizedBox(height: 6),
          if (consultations.isEmpty)
            _videMsg('Aucune consultation enregistree', fontItalic)
          else
            ...consultations.map((c) => _carteConsultation(
                c, fontBold, fontRegular, styleGris)),
          pw.SizedBox(height: 14),

          // ── Vaccinations ─────────────────────────────────
          _titreSection('Carnet de Vaccinations', _bleu, fontBold),
          pw.SizedBox(height: 6),
          if (vaccinations.isEmpty)
            _videMsg('Aucune vaccination enregistree', fontItalic)
          else
            ...vaccinations.map((v) => _carteVaccination(
                v, fontBold, fontRegular, styleGris)),
          pw.SizedBox(height: 14),

          // ── Mentions ─────────────────────────────────────
          pw.Container(
            padding   : const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color       : _orangeClair,
              borderRadius: pw.BorderRadius.circular(6),
              border      : pw.Border.all(
                  color: const PdfColor.fromInt(0xFFFFB300), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Document officiel',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 10, color: _orange)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ce carnet de sante est genere automatiquement par '
                  'l\'application JUR GUI. Les informations proviennent des '
                  'enregistrements effectues par les veterinaires accredites. '
                  'Genere le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}.',
                  style: pw.TextStyle(
                      font: fontRegular, fontSize: 8, color: _gris),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ─── En-tête ──────────────────────────────────────────────
  static pw.Widget _header(
      String nomAnimal, String dateGen, pw.Font bold, pw.Font regular) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _vert, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('JUR GUI',
                style: pw.TextStyle(font: bold, fontSize: 20, color: _vert)),
            pw.Text('Carnet de Sante Animal',
                style: pw.TextStyle(font: regular, fontSize: 11, color: _gris)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(nomAnimal,
                style: pw.TextStyle(font: bold, fontSize: 14, color: _noir)),
            pw.Text('Genere le $dateGen',
                style: pw.TextStyle(font: regular, fontSize: 8, color: _gris)),
          ]),
        ],
      ),
    );
  }

  // ─── Pied de page ─────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, pw.Font regular) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _gris, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('JUR GUI - Gestion d\'elevage',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _gris)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _gris)),
        ],
      ),
    );
  }

  // ─── Carte consultation ────────────────────────────────────
  static pw.Widget _carteConsultation(Map<String, dynamic> c,
      pw.Font bold, pw.Font regular, pw.TextStyle styleGris) {
    return pw.Container(
      margin    : const pw.EdgeInsets.only(bottom: 8),
      padding   : const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color       : _grisClair,
        borderRadius: pw.BorderRadius.circular(6),
        border      : pw.Border.all(color: _vert, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _fmtDate(c['date_acte']?.toString()),
                style: pw.TextStyle(font: bold, fontSize: 10, color: _vert),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color       : _vert,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('CONSULTATION',
                    style: pw.TextStyle(
                        font: bold, fontSize: 7, color: PdfColors.white)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _ligne('Motif'      , c['titre']?.toString()           ?? 'N/A', bold, regular),
          _ligne('Diagnostic' , c['diagnostic']?.toString()      ?? 'N/A', bold, regular),
          _ligne('Traitement' , c['traitement']?.toString()      ?? 'N/A', bold, regular),
          _ligne('Veterinaire', c['veterinaire_nom']?.toString() ?? 'N/A', bold, regular),
          if (c['temperature_c'] != null)
            _ligne('Temperature', '${c['temperature_c']} C',              bold, regular),
          if (c['poids_kg'] != null)
            _ligne('Poids',       '${c['poids_kg']} kg',                  bold, regular),
          if (c['observations'] != null &&
              c['observations'].toString().isNotEmpty)
            _ligne('Observations', c['observations'].toString(),           bold, regular),
        ],
      ),
    );
  }

  // ─── Carte vaccination ─────────────────────────────────────
  static pw.Widget _carteVaccination(Map<String, dynamic> v,
      pw.Font bold, pw.Font regular, pw.TextStyle styleGris) {
    return pw.Container(
      margin    : const pw.EdgeInsets.only(bottom: 8),
      padding   : const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color       : _grisClair,
        borderRadius: pw.BorderRadius.circular(6),
        border      : pw.Border.all(color: _bleu, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _fmtDate(v['date_acte']?.toString()),
                style: pw.TextStyle(font: bold, fontSize: 10, color: _bleu),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color       : _bleu,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('VACCINATION',
                    style: pw.TextStyle(
                        font: bold, fontSize: 7, color: PdfColors.white)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _ligne('Vaccin'     , v['nom_vaccin']?.toString()      ?? 'N/A', bold, regular),
          _ligne('Veterinaire', v['veterinaire_nom']?.toString() ?? 'N/A', bold, regular),
          if (v['date_rappel'] != null)
            _ligne('Rappel prevu', _fmtDate(v['date_rappel']?.toString()), bold, regular),
          if (v['lot'] != null && v['lot'].toString().isNotEmpty)
            _ligne('N de lot', v['lot'].toString(), bold, regular),
          if (v['observations'] != null &&
              v['observations'].toString().isNotEmpty)
            _ligne('Observations', v['observations'].toString(), bold, regular),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────
  static pw.Widget _titreSection(
      String titre, PdfColor couleur, pw.Font bold) {
    return pw.Container(
      width  : double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      decoration: pw.BoxDecoration(
        color       : couleur,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(titre,
          style: pw.TextStyle(
              font: bold, fontSize: 12, color: PdfColors.white)),
    );
  }

  static pw.Widget _statBox(String valeur, String label,
      PdfColor couleur, PdfColor bg, pw.Font bold, pw.Font regular) {
    return pw.Container(
      padding   : const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color       : bg,
        borderRadius: pw.BorderRadius.circular(6),
        border      : pw.Border.all(color: couleur, width: 0.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(valeur,
              style: pw.TextStyle(
                  font: bold, fontSize: 22, color: couleur),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 4),
          pw.Text(label,
              style: pw.TextStyle(
                  font: regular, fontSize: 9, color: couleur),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _infoLigne(
      String label, String valeur, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 8, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: bold, fontSize: 8, color: _gris)),
          pw.SizedBox(height: 2),
          pw.Text(valeur,
              style: pw.TextStyle(
                  font: regular, fontSize: 10, color: _noir)),
        ],
      ),
    );
  }

  static pw.Widget _ligne(
      String label, String valeur, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text('$label :',
                style: pw.TextStyle(
                    font: bold, fontSize: 9, color: _gris)),
          ),
          pw.Expanded(
            child: pw.Text(valeur,
                style: pw.TextStyle(
                    font: regular, fontSize: 9, color: _noir)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _videMsg(String msg, pw.Font italic) {
    return pw.Container(
      width  : double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color       : _grisClair,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(msg,
          style    : pw.TextStyle(font: italic, fontSize: 10, color: _gris),
          textAlign: pw.TextAlign.center),
    );
  }

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}