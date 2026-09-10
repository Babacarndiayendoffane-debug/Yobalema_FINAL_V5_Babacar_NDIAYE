/// Helper pour nettoyer et formater les messages d'erreur affichés aux utilisateurs.
/// Empêche l'affichage de messages techniques bruts (ex: ClientException, URLs localhost, etc.).

String cleanErrorMessage(dynamic error) {
  if (error == null) return 'Une erreur est survenue.';
  
  String msg = error.toString().trim();
  
  // Supprimer les préfixes d'exceptions Dart courantes
  if (msg.startsWith('Exception: ')) {
    msg = msg.substring(11).trim();
  }
  if (msg.startsWith('ClientException: ')) {
    msg = msg.substring(17).trim();
  }
  if (msg.startsWith('FormatException: ')) {
    msg = msg.substring(17).trim();
  }
  
  final lower = msg.toLowerCase();
  
  // Détection des erreurs réseau / fetch / socket / localhost
  if (lower.contains('failed to fetch') ||
      lower.contains('clientfailed') ||
      lower.contains('clientexception') ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('handshakeexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('network is unreachable') ||
      lower.contains('localhost:4000') ||
      lower.contains('10.0.2.2:4000') ||
      lower.contains('failed host lookup') ||
      lower.contains('os error') ||
      lower.contains('errno = 111') ||
      lower.contains('errno = 10061')) {
    return 'Serveur injoignable. Vérifiez votre connexion internet ou réessayez plus tard.';
  }
  
  return msg;
}
