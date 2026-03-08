import 'dart:convert';

import 'package:http/http.dart' as http;

class CurrencyRateService {
  static const String _endpoint = 'https://api.exchangerate.host/latest';

  Future<Map<String, double>> fetchRatesToMyr({
    required List<String> symbols,
  }) async {
    final uniqueSymbols = symbols.toSet().toList()..sort();
    if (uniqueSymbols.isEmpty) return {};

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {'base': 'MYR', 'symbols': uniqueSymbols.join(',')},
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Rate request failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = body['rates'];
    if (rates is! Map<String, dynamic>) {
      throw Exception('Invalid rate response');
    }

    final result = <String, double>{};
    result['MYR'] = 1;

    for (final entry in rates.entries) {
      final code = entry.key;
      final value = (entry.value as num).toDouble();
      if (code == 'MYR') {
        result['MYR'] = 1;
        continue;
      }
      if (value <= 0) continue;
      // API returns foreign per 1 MYR. We need MYR per 1 foreign.
      result[code] = 1 / value;
    }

    return result;
  }
}
