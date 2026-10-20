class AppConstants {
  AppConstants._();

  static const String appName = 'Gerak-in';

  static const String supabaseUrl = 'https://plybkkjxygefwukatzzb.supabase.co';

  static const String registerEndpoint =
      '$supabaseUrl/functions/v1/auth-register';

  static const String loginEndpoint = '$supabaseUrl/functions/v1/auth-login';
}
