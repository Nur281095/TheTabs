import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/message.dart';
import '../services/chat_tab_service.dart';
import '../services/message_service.dart';
import '../config/ai_config.dart';

class TopicDetectionService {
  static final TopicDetectionService _instance = TopicDetectionService._internal();
  factory TopicDetectionService() => _instance;
  TopicDetectionService._internal();

  final ChatTabService _chatTabService = ChatTabService();
  final MessageService _messageService = MessageService();
  
  late final GenerativeModel _model;
  
  // Cache to track which tabs have been analyzed
  final Map<String, bool> _analyzedTabs = {};
  
  void initialize() {
    if (!AIConfig.isConfigured) {
      print('⚠️ Warning: Gemini API key not configured. Please add your API key in lib/config/ai_config.dart');
      print('📝 Get your free API key from: https://makersuite.google.com/app/apikey');
      return;
    }
    
    _model = GenerativeModel(
      model: AIConfig.aiModel,
      apiKey: AIConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: AIConfig.temperature,
        topK: AIConfig.topK,
        topP: AIConfig.topP,
        maxOutputTokens: AIConfig.maxOutputTokens,
      ),
    );
    
    print('✅ AI Topic Detection initialized successfully');
  }

  /// Analyze messages in a tab and auto-rename if topic detected
  Future<String?> analyzeAndRenameTab(String tabId) async {
    try {
      // Check if already analyzed
      if (_analyzedTabs[tabId] == true) {
        return null;
      }
      
      // Get messages from the tab
      final messages = await _messageService.getTabMessagesFuture(
        tabId,
        limit: AIConfig.maxMessagesToAnalyze,
      );
      
      // Check if we have enough messages
      if (messages.length < AIConfig.minMessagesForDetection) {
        return null;
      }
      
      // Get current tab info
      final tab = await _chatTabService.getTab(tabId);
      if (tab == null) return null;
      
      // Skip if tab already has a custom name (not default "Topic X" pattern)
      if (!_isDefaultTabName(tab.tabName)) {
        _analyzedTabs[tabId] = true;
        return null;
      }
      
      // Detect topic
      final detectedTopic = await detectTopicFromMessages(messages);
      
      if (detectedTopic != null && detectedTopic.isNotEmpty) {
        // Update tab name
        final success = await _chatTabService.updateTabName(tabId, detectedTopic);
        
        if (success) {
          _analyzedTabs[tabId] = true;
          print('✅ Tab renamed to: $detectedTopic');
          return detectedTopic;
        }
      }
      
      return null;
    } catch (e) {
      print('Error analyzing tab: $e');
      return null;
    }
  }

  /// Detect topic from a list of messages using Gemini AI
  Future<String?> detectTopicFromMessages(List<MessageModel> messages) async {
    try {
      if (!AIConfig.isConfigured) {
        // Fallback to rule-based detection if API key not configured
        return _fallbackTopicDetection(messages);
      }
      
      // Filter only text messages
      final textMessages = messages
          .where((m) => m.messageType == MessageType.text && m.content != null)
          .toList();
      
      if (textMessages.isEmpty) {
        return null;
      }
      
      // Build conversation context for AI
      final conversationText = _buildConversationContext(textMessages);
      
      // Create prompt for Gemini
      final prompt = '''
Analyze the following conversation and generate a short, descriptive topic name (2-5 words max).
The topic should be concise, clear, and capture the main subject being discussed.

Rules:
- Maximum 5 words
- Use lowercase for better readability (e.g., "pets app discussion")
- Be specific but concise
- Don't use quotes in the response
- If no clear topic, respond with just "general chat"

Conversation:
$conversationText

Topic name:''';

      // Call Gemini API
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text != null && response.text!.isNotEmpty) {
        String topic = response.text!.trim();
        
        // Clean up the response
        topic = topic.replaceAll('"', '').replaceAll("'", '');
        topic = topic.toLowerCase();
        
        // Limit length
        if (topic.split(' ').length > 5) {
          topic = topic.split(' ').take(5).join(' ');
        }
        
        return topic;
      }
      
      return null;
    } catch (e) {
      print('Error detecting topic with Gemini: $e');
      // Fallback to rule-based detection
      return _fallbackTopicDetection(messages);
    }
  }

  /// Build conversation context from messages
  String _buildConversationContext(List<MessageModel> messages) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < messages.length && i < AIConfig.maxMessagesToAnalyze; i++) {
      final message = messages[i];
      if (message.content != null && message.content!.isNotEmpty) {
        buffer.writeln('- ${message.content}');
      }
    }
    
    return buffer.toString();
  }

  /// Fallback rule-based topic detection (when AI is not available)
  String? _fallbackTopicDetection(List<MessageModel> messages) {
    try {
      // Extract keywords from messages
      final allText = messages
          .where((m) => m.content != null)
          .map((m) => m.content!)
          .join(' ')
          .toLowerCase();
      
      // Simple keyword extraction
      final words = allText
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((w) => w.length > 3)
          .toList();
      
      // Count word frequency
      final wordCount = <String, int>{};
      for (final word in words) {
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      }
      
      // Remove common words
      final commonWords = {
        'that', 'this', 'with', 'from', 'have', 'been', 'were', 'said',
        'what', 'when', 'where', 'which', 'their', 'there', 'would', 'could',
        'should', 'about', 'after', 'before', 'just', 'also', 'more', 'some',
        'very', 'know', 'think', 'want', 'need', 'like', 'well', 'much',
        'many', 'your', 'mine', 'going', 'doing', 'make', 'take', 'yeah',
        'okay', 'sure', 'really', 'maybe', 'hello', 'thanks', 'please'
      };
      
      wordCount.removeWhere((key, value) => commonWords.contains(key));
      
      // Get top 3 keywords
      final topKeywords = wordCount.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      if (topKeywords.isNotEmpty) {
        final topic = topKeywords
            .take(3)
            .map((e) => e.key)
            .join(' ');
        return topic.length > 30 ? topic.substring(0, 30) : topic;
      }
      
      return null;
    } catch (e) {
      print('Error in fallback topic detection: $e');
      return null;
    }
  }

  /// Check if tab name is a default name (like "Topic 1", "Topic 2", etc.)
  bool _isDefaultTabName(String tabName) {
    // Check if it matches patterns like "Topic 1", "Topic 2", "Tab 1", etc.
    final pattern = RegExp(r'^(Topic|Tab)\s*\d+$', caseSensitive: false);
    return pattern.hasMatch(tabName);
  }

  /// Manually trigger topic detection for a tab
  Future<String?> manuallyDetectTopic(String tabId) async {
    _analyzedTabs.remove(tabId); // Remove from cache to force re-analysis
    return await analyzeAndRenameTab(tabId);
  }

  /// Reset analysis cache for a tab
  void resetTabAnalysis(String tabId) {
    _analyzedTabs.remove(tabId);
  }

  /// Clear all analysis cache
  void clearCache() {
    _analyzedTabs.clear();
  }

  /// Check if a tab should be analyzed (has enough messages)
  Future<bool> shouldAnalyzeTab(String tabId) async {
    try {
      if (_analyzedTabs[tabId] == true) {
        return false;
      }
      
      final messages = await _messageService.getTabMessagesFuture(
        tabId,
        limit: AIConfig.minMessagesForDetection + 1,
      );
      
      return messages.length >= AIConfig.minMessagesForDetection;
    } catch (e) {
      print('Error checking if tab should be analyzed: $e');
      return false;
    }
  }
}

