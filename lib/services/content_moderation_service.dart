// lib/services/content_moderation_service.dart

class ContentModerationService {
  // Lista extensa de palabras prohibidas en español
  static const List<String> _baseBannedWords = [
    // Insultos comunes
    'puta', 'puto', 'zorra', 'zorro', 'cabron', 'cabrona', 'joder', 'jodido',
    'maricon', 'marica', 'maricona', 'bollera', 'tortillera', 'sudaca',
    'mierda', 'cagada', 'cagon', 'gilipollas', 'gilipolla', 'tonto', 'tonta',
    'imbecil', 'idiota', 'estupido', 'estupida', 'retrasado', 'retrasada',
    'subnormal', 'mongoloide', 'tarado', 'tarada', 'pendejo', 'pendeja',
    'coño', 'cojones', 'hostia', 'ostia', 'leche', 'pollas', 'polla',
    'verga', 'carajo', 'chingar', 'chingada', 'chingado', 'culero', 'culera',
    'hijodeputa', 'hijo de puta', 'hijaputa', 'hija de puta', 'malparido',
    'gonorrea', 'huevon', 'guevon', 'pelotudo', 'boludo', 'forro',

    'fuck', 'shit', 'asshole', 'bitch', 'bastard', 'cunt', 'dick', 'pussy', 
    'nigger', 'faggot', 'retard', 'porn', 'sex', 'drugs', 'cocaine', 'murder', 
    'kill', 'suicide', 'bomb', 'terrorist'

    // Contenido sexual explícito
    'tetas', 'teta', 'pezones', 'pezon', 'vagina', 'vulva', 'clitoris',
    'pene', 'polla', 'verga', 'rabo', 'nabo', 'cipote', 'poronga', 'pija',
    'coger', 'follar', 'culear', 'tirar', 'chingar', 'singando', 'culeando',
    'mamada', 'mamadas', 'corrida', 'correrse', 'pajero', 'pajera',
    'masturbar', 'masturbacion', 'pajear', 'paja', 'hacerse una paja',
    'sexo oral', 'cunnilingus', 'felacion', 'felacio', 'sodomia',
    'anal', 'culo', 'culo roto', 'ojete', 'ano', 'trasero', 'nalgas',
    'orgasmo', 'orgasmica', 'excitado', 'excitada', 'cachondo', 'cachonda',
    'caliente', 'calenton', 'arrecho', 'arrecha', 'salido', 'salida',
    'penetrar', 'penetracion', 'chupar', 'lamer', 'mamar',

    // Términos racistas y discriminatorios
    'negro de mierda', 'sudaca', 'panchito', 'chino de mierda', 'moro',
    'gitano', 'gitana', 'payo', 'paya', 'gabacho', 'guiri', 'indio',
    'gordo', 'gorda', 'obeso', 'obesa', 'ballena', 'cerdo', 'cerda',
    'enano', 'enana', 'deforme', 'feo', 'fea', 'horroroso', 'horrorosa',
    'facha', 'rojo', 'comunista', 'facha', 'fascista', 'nazi',

    // Drogas
    'drogas', 'droga', 'cocaina', 'coca', 'farlopa', 'perico',
    'heroina', 'caballo', 'heroína', 'speed', 'anfeta', 'anfetas',
    'extasis', 'mdma', 'pastillas', 'tripis', 'acido', 'lsd',
    'maria', 'marihuana', 'hierba', 'porro', 'porros', 'canuto',
    'hachis', 'chocolate', 'keta', 'ketamina', 'cristal', 'meta',
    'trafico', 'traficante', 'camello', 'dealer', 'trapicheo',
    'colocarse', 'drogarse', 'esnifar', 'fumar porros',

    // Violencia
    'matar', 'asesinar', 'violar', 'violacion', 'secuestrar', 'secuestro',
    'pegar', 'golpear', 'torturar', 'tortura', 'mutilar', 'mutilacion',
    'suicidio', 'suicidarme', 'matarme', 'cortarme', 'autolesion',
    'disparo', 'disparar', 'cuchillo', 'apuñalar', 'degollar',

    // Spam/Comercial
    'compra ya', 'click aqui', 'haz click', 'descuento', 'oferta limitada',
    'gana dinero', 'dinero facil', 'hazte rico', 'trabajo desde casa',
    'bitcoin gratis', 'crypto', 'inversion', 'prestamo', 'credito',
    'casino', 'apuesta', 'poker', 'ruleta', 'slots',
    'whatsapp', 'telegram', 'contactame', 'llamame', 'escribeme',

    // Otros términos inapropiados
    'nazi', 'hitler', 'holocausto', 'terrorista', 'bomba', 'atentado',
    'pederasta', 'pedofilo', 'pedofilia', 'violador', 'asesino',
    'prostituta', 'escort', 'scort', 'acompañante', 'puta',
    'piruja', 'zorra', 'ramera', 'fulana',
  ];

  /// Lista final expandida (diminutivos, aumentativos, plurales)
  static final List<String> _bannedWords = _expandWords(_baseBannedWords);

  static List<String> _expandWords(List<String> words) {
    const diminutives = ['ito', 'ita', 'illo', 'illa', 'ico', 'ica'];
    const augmentatives = ['on', 'ona', 'azo', 'aza', 'ote', 'ota'];
    const plurals = ['s', 'es'];

    final Set<String> expanded = {};

    for (final word in words) {
      expanded.add(word);

      // Plurales
      for (final p in plurals) {
        expanded.add(word + p);
      }

      // Diminutivos
      for (final d in diminutives) {
        expanded.add(word + d);
        for (final p in plurals) {
          expanded.add(word + d + p);
        }
      }

      // Aumentativos
      for (final a in augmentatives) {
        expanded.add(word + a);
        for (final p in plurals) {
          expanded.add(word + a + p);
        }
      }
    }

    return expanded.toList();
  }

  /// Normaliza el texto para detectar variaciones
  static String _normalizeText(String text) {
    String normalized = text.toLowerCase();

    // Quitar espacios
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');

    // Números por letras
    normalized = normalized
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('8', 'b');

    // Caracteres especiales
    normalized = normalized
        .replaceAll('@', 'a')
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('\$', 's')
        .replaceAll('%', '')
        .replaceAll('&', '')
        .replaceAll('+', 't')
        .replaceAll('!', 'i')
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '');

    return normalized;
  }

  /// Verifica si el texto contiene contenido inapropiado
  static ModerationResult checkContent(String text) {
    if (text.trim().isEmpty) {
      return ModerationResult(isClean: true);
    }

    final normalized = _normalizeText(text);

    for (final bannedWord in _bannedWords) {
      final normalizedBannedWord = _normalizeText(bannedWord);
      if (normalized.contains(normalizedBannedWord)) {
        return ModerationResult(
          isClean: false,
          detectedWord: bannedWord,
          originalText: text,
        );
      }
    }

    return ModerationResult(isClean: true);
  }

  /// Valida múltiples campos de un spot
  static ModerationResult validateSpotContent({
    required String name,
    required String description,
  }) {
    final nameResult = checkContent(name);
    if (!nameResult.isClean) {
      return nameResult.copyWith(field: 'nombre');
    }

    final descResult = checkContent(description);
    if (!descResult.isClean) {
      return descResult.copyWith(field: 'descripción');
    }

    return ModerationResult(isClean: true);
  }

  /// Sustituye palabras prohibidas por ***
  static String cleanText(String text) {
    String cleaned = text;

    for (final bannedWord in _bannedWords) {
      final regex = RegExp(bannedWord, caseSensitive: false);
      cleaned = cleaned.replaceAll(regex, '***');
    }

    return cleaned;
  }
}

/// Resultado de la moderación
class ModerationResult {
  final bool isClean;
  final String? detectedWord;
  final String? originalText;
  final String? field;

  ModerationResult({
    required this.isClean,
    this.detectedWord,
    this.originalText,
    this.field,
  });

  ModerationResult copyWith({
    bool? isClean,
    String? detectedWord,
    String? originalText,
    String? field,
  }) {
    return ModerationResult(
      isClean: isClean ?? this.isClean,
      detectedWord: detectedWord ?? this.detectedWord,
      originalText: originalText ?? this.originalText,
      field: field ?? this.field,
    );
  }

  String get errorMessage {
    if (isClean) return '';
    final fieldText = field != null ? 'en el $field' : '';
    return 'Se detectó contenido inapropiado $fieldText. '
        'Por favor, revisa el texto e inténtalo de nuevo.';
  }
}