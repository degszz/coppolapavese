import 'dart:convert';
import 'dart:io';

/// Servicio para consultar y controlar la cola de impresión de Windows.
///
/// Usa PowerShell + WMI (`Win32_PrintJob`, `Win32_Printer`) porque no requiere
/// dependencias adicionales y es el camino más robusto en Windows 10/11.
class PrintQueueService {
  /// Devuelve todos los trabajos de impresión activos en cualquier impresora.
  static Future<List<PrintJob>> listarTrabajos() async {
    if (!Platform.isWindows) return [];

    const cmd =
        'Get-CimInstance -ClassName Win32_PrintJob -ErrorAction SilentlyContinue | '
        'Select-Object JobId,Document,Status,JobStatus,TotalPages,PagesPrinted,Size,TimeSubmitted,Owner,Name | '
        'ConvertTo-Json -Compress -Depth 2';

    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', cmd],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) return [];
      final out = (res.stdout as String).trim();
      if (out.isEmpty) return [];

      final decoded = jsonDecode(out);
      final lista = decoded is List ? decoded : [decoded];
      return lista
          .map((j) => PrintJob.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Devuelve todas las impresoras instaladas con su estado.
  static Future<List<PrinterInfo>> listarImpresoras() async {
    if (!Platform.isWindows) return [];

    const cmd =
        'Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue | '
        'Select-Object Name,Default,Network,PrinterStatus,DetectedErrorState,WorkOffline,PortName | '
        'ConvertTo-Json -Compress -Depth 2';

    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', cmd],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) return [];
      final out = (res.stdout as String).trim();
      if (out.isEmpty) return [];

      final decoded = jsonDecode(out);
      final lista = decoded is List ? decoded : [decoded];
      return lista
          .map((p) => PrinterInfo.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cancela un trabajo de impresión específico.
  static Future<bool> cancelarTrabajo(String printerName, int jobId) async {
    if (!Platform.isWindows) return false;
    // Escapar comillas simples en el nombre de la impresora
    final safePrinter = printerName.replaceAll("'", "''");
    final cmd =
        "Remove-PrintJob -PrinterName '$safePrinter' -ID $jobId -ErrorAction SilentlyContinue";
    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', cmd],
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Cancela TODOS los trabajos de una impresora.
  static Future<bool> vaciarCola(String printerName) async {
    if (!Platform.isWindows) return false;
    final safePrinter = printerName.replaceAll("'", "''");
    final cmd =
        "Get-PrintJob -PrinterName '$safePrinter' -ErrorAction SilentlyContinue | "
        "Remove-PrintJob -ErrorAction SilentlyContinue";
    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', cmd],
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Reinicia el servicio de cola de impresión (Print Spooler).
  /// Requiere permisos de admin — devuelve false si falla.
  static Future<bool> reiniciarSpooler() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Restart-Service -Name Spooler -Force -ErrorAction Stop'
        ],
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// MODELOS
// ════════════════════════════════════════════════════════════════

class PrintJob {
  final int jobId;
  final String document;
  final String printerName;
  /// Estado crudo (uint32 de WMI) — usamos [jobStatus] como texto
  final int statusCode;
  final String jobStatus;
  final int totalPages;
  final int pagesPrinted;
  final int sizeBytes;
  final DateTime? timeSubmitted;
  final String owner;

  PrintJob({
    required this.jobId,
    required this.document,
    required this.printerName,
    required this.statusCode,
    required this.jobStatus,
    required this.totalPages,
    required this.pagesPrinted,
    required this.sizeBytes,
    required this.timeSubmitted,
    required this.owner,
  });

  factory PrintJob.fromJson(Map<String, dynamic> j) {
    // `Name` viene como "Impresora, NN" — extraemos el nombre de impresora
    final rawName = (j['Name'] as String?) ?? '';
    final partes = rawName.split(',');
    final printer = partes.isNotEmpty ? partes.first.trim() : '';

    return PrintJob(
      jobId: (j['JobId'] as num?)?.toInt() ?? 0,
      document: (j['Document'] as String?) ?? '',
      printerName: printer,
      statusCode: (j['Status'] as num?)?.toInt() ?? 0,
      jobStatus: (j['JobStatus']?.toString() ?? '').trim(),
      totalPages: (j['TotalPages'] as num?)?.toInt() ?? 0,
      pagesPrinted: (j['PagesPrinted'] as num?)?.toInt() ?? 0,
      sizeBytes: (j['Size'] as num?)?.toInt() ?? 0,
      timeSubmitted: _parseWmiDate(j['TimeSubmitted']),
      owner: (j['Owner'] as String?) ?? '',
    );
  }

  /// Texto en español del estado del trabajo (si lo podemos interpretar)
  String get estadoTexto {
    final js = jobStatus.toLowerCase();
    if (js.contains('print')) return 'Imprimiendo';
    if (js.contains('spool')) return 'En cola';
    if (js.contains('paused')) return 'Pausado';
    if (js.contains('error')) return 'Error';
    if (js.contains('offline')) return 'Sin conexión';
    if (js.contains('paper')) return 'Falta papel';
    if (js.contains('delet')) return 'Eliminando';
    if (js.isEmpty) return 'En cola';
    return jobStatus;
  }

  /// Progreso 0..1 (o null si no se conoce)
  double? get progreso {
    if (totalPages <= 0) return null;
    return (pagesPrinted / totalPages).clamp(0.0, 1.0);
  }
}

class PrinterInfo {
  final String name;
  final bool isDefault;
  final bool isNetwork;
  final int statusCode;
  final int detectedErrorState;
  final bool workOffline;
  final String portName;

  PrinterInfo({
    required this.name,
    required this.isDefault,
    required this.isNetwork,
    required this.statusCode,
    required this.detectedErrorState,
    required this.workOffline,
    required this.portName,
  });

  factory PrinterInfo.fromJson(Map<String, dynamic> j) {
    return PrinterInfo(
      name: (j['Name'] as String?) ?? '',
      isDefault: (j['Default'] as bool?) ?? false,
      isNetwork: (j['Network'] as bool?) ?? false,
      statusCode: (j['PrinterStatus'] as num?)?.toInt() ?? 0,
      detectedErrorState: (j['DetectedErrorState'] as num?)?.toInt() ?? 0,
      workOffline: (j['WorkOffline'] as bool?) ?? false,
      portName: (j['PortName'] as String?) ?? '',
    );
  }

  /// WMI PrinterStatus:
  /// 1 Other, 2 Unknown, 3 Idle, 4 Printing, 5 Warmup,
  /// 6 Stopped, 7 Offline
  String get estadoTexto {
    if (workOffline) return 'Sin conexión';
    switch (statusCode) {
      case 3:
        return 'Lista';
      case 4:
        return 'Imprimiendo';
      case 5:
        return 'Calentando';
      case 6:
        return 'Detenida';
      case 7:
        return 'Sin conexión';
      default:
        return 'Desconocido';
    }
  }

  /// DetectedErrorState:
  /// 0 Unknown, 1 Other, 2 No Error, 3 Low Paper, 4 No Paper,
  /// 5 Low Toner, 6 No Toner, 7 Door Open, 8 Jammed,
  /// 9 Offline, 10 Service Requested, 11 Output Bin Full
  String? get errorTexto {
    switch (detectedErrorState) {
      case 3:
        return 'Poco papel';
      case 4:
        return 'Sin papel';
      case 5:
        return 'Poco tóner';
      case 6:
        return 'Sin tóner';
      case 7:
        return 'Tapa abierta';
      case 8:
        return 'Atasco de papel';
      case 9:
        return 'Sin conexión';
      case 10:
        return 'Requiere mantenimiento';
      case 11:
        return 'Bandeja llena';
      default:
        return null;
    }
  }

  /// True si la impresora está operativa (lista o imprimiendo).
  bool get estaLista =>
      !workOffline && (statusCode == 3 || statusCode == 4 || statusCode == 5);
}

/// Parsea fechas WMI tipo `/Date(1700000000000)/` o ISO 8601.
DateTime? _parseWmiDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  // Formato `/Date(1700000000000)/`
  final m = RegExp(r'/Date\((\d+)').firstMatch(s);
  if (m != null) {
    final ms = int.tryParse(m.group(1) ?? '');
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}
