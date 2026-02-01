class ApiConfig {
  static const String baseUrl = "https://ayush-backend-rali.onrender.com";
  
  static const String register = "$baseUrl/register";
  static const String login = "$baseUrl/login";
  static const String updatePrakriti = "$baseUrl/update_prakriti";
  // NEW: Fetch profile
  static String userProfile(String phone) => "$baseUrl/user_profile/$phone";
  static const String scanMeal = "$baseUrl/scan_meal";
}