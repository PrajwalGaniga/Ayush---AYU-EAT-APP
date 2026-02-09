class ApiConfig {
  // REMOVE the trailing slash at the end
  static const String baseUrl = "https://dawdlingly-pseudoinsane-pa.ngrok-free.dev";
  
  static const String register = "$baseUrl/register";
  static const String login = "$baseUrl/login";
  static const String updatePrakriti = "$baseUrl/update_prakriti";
  static String userProfile(String phone) => "$baseUrl/user_profile/$phone";
  static const String scanMeal = "$baseUrl/scan_meal";
}