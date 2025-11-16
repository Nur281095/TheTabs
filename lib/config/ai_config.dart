/// AI Configuration for Topic Detection
/// 
/// To enable AI-powered topic detection:
/// 1. Get a free Gemini API key from: https://makersuite.google.com/app/apikey
/// 2. Replace the placeholder below with your actual API key
/// 3. IMPORTANT: For production, use environment variables or secure storage
class AIConfig {
  /// Gemini API Key
  /// Get your free API key from: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = 'AIzaSyAroDX5Z7eKAI7s-3pGE41i9_hca-qJ768';
  
  /// Check if API key is configured
  static bool get isConfigured => geminiApiKey != 'AIzaSyAroDX5Z7eKAI7s-3pGE41i9_hca-qJ768';
  
  /// Minimum messages before triggering topic detection
  static const int minMessagesForDetection = 5;
  
  /// Maximum messages to analyze for topic detection
  static const int maxMessagesToAnalyze = 15;
  
  /// AI Model configuration
  static const String aiModel = 'gemini-1.5-flash'; // Fast and free tier available
  
  /// AI generation parameters
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 100;
}

