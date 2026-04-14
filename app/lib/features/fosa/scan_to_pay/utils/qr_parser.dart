/// Parses M-Pesa / EMV QR codes into a structured result.
///
/// M-Pesa QR codes follow the EMV Co. Merchant QR spec.
/// Relevant tags:
///   26 → Paybill  (sub-tag 01 = business number, 02 = account number)
///   29 → Till / Buy Goods (sub-tag 01 = till number)
///   54 → Transaction amount
class QrParseResult {
  final String type; // 'paybill' | 'till' | 'unknown'
  final String? businessNumber;
  final String? accountNumber;
  final String? tillNumber;
  final double? amount;

  const QrParseResult({
    required this.type,
    this.businessNumber,
    this.accountNumber,
    this.tillNumber,
    this.amount,
  });

  bool get isValid => type == 'paybill' || type == 'till';
}

class QrParser {
  static QrParseResult parse(String raw) {
    try {
      final tags = _parseTlv(raw);

      // Tag 54 — optional amount
      final double? amount = tags.containsKey('54')
          ? double.tryParse(tags['54']!)
          : null;

      // Tag 26 — Paybill
      if (tags.containsKey('26')) {
        final sub = _parseTlv(tags['26']!);
        return QrParseResult(
          type: 'paybill',
          businessNumber: sub['01'],
          accountNumber: sub['02'],
          amount: amount,
        );
      }

      // Tag 29 — Till (Buy Goods)
      if (tags.containsKey('29')) {
        final sub = _parseTlv(tags['29']!);
        return QrParseResult(
          type: 'till',
          tillNumber: sub['01'],
          amount: amount,
        );
      }

      return const QrParseResult(type: 'unknown');
    } catch (_) {
      return const QrParseResult(type: 'unknown');
    }
  }

  /// Parses EMV TLV string: each entry is 2-char tag + 2-char length + value
  static Map<String, String> _parseTlv(String data) {
    final result = <String, String>{};
    int i = 0;
    while (i + 4 <= data.length) {
      final tag = data.substring(i, i + 2);
      final len = int.tryParse(data.substring(i + 2, i + 4)) ?? 0;
      if (i + 4 + len > data.length) break;
      final value = data.substring(i + 4, i + 4 + len);
      result[tag] = value;
      i += 4 + len;
    }
    return result;
  }
}
