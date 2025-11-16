# 🤖 AI-Powered Topic Detection - Setup Guide

## Overview

Your TABS chat application now features **AI-powered automatic tab renaming**! When users chat in a tab, the system analyzes the conversation and automatically renames the tab from generic names like "Topic 1" to meaningful names like "pets app discussion".

## 🎯 Features

- ✅ **Automatic Topic Detection**: Analyzes chat messages using Google's Gemini AI
- ✅ **Smart Renaming**: Renames tabs automatically after 5 messages
- ✅ **Fallback Mode**: Works even without AI (uses keyword extraction)
- ✅ **Non-Blocking**: Doesn't affect chat performance
- ✅ **Free Tier**: Uses Gemini 1.5 Flash (free tier available)

## 🚀 Quick Setup (5 minutes)

### Step 1: Get Your Free Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated API key

### Step 2: Install Dependencies

Run the following command in your project directory:

```bash
flutter pub get
```

This will install:
- `google_generative_ai` - Google's Gemini AI SDK
- `http` - HTTP client for API calls

### Step 3: Configure API Key

Open the file: `lib/config/ai_config.dart`

Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key:

```dart
class AIConfig {
  /// Gemini API Key
  static const String geminiApiKey = 'AIzaSyD...your-actual-key...';
  // ... rest of the file
}
```

### Step 4: Run Your App

```bash
flutter run
```

That's it! The AI topic detection is now active.

## 📝 How It Works

### Automatic Detection Flow

1. **User sends messages** in a tab
2. **After 5 messages**, the system triggers topic detection
3. **AI analyzes** the conversation and generates a topic name
4. **Tab is renamed** automatically (e.g., "Topic 1" → "project planning")
5. **Only once per tab** - won't rename already-renamed tabs

### Example Scenarios

| Messages | Original Tab Name | AI-Detected Topic |
|----------|------------------|-------------------|
| "Let's discuss the new pet app features" | Topic 1 | pets app discussion |
| "Can you help with React component design?" | Topic 2 | react component design |
| "Meeting at 3pm to discuss Q4 budget" | Topic 3 | q4 budget meeting |
| "I'm planning a trip to Paris next month" | Topic 4 | paris trip planning |

## ⚙️ Configuration Options

Edit `lib/config/ai_config.dart` to customize:

```dart
class AIConfig {
  // Minimum messages before triggering detection
  static const int minMessagesForDetection = 5;  // Change to 3, 10, etc.
  
  // Maximum messages to analyze
  static const int maxMessagesToAnalyze = 15;    // Change to 10, 20, etc.
  
  // AI model
  static const String aiModel = 'gemini-1.5-flash'; // Fast & free
  
  // Temperature (creativity): 0.0 to 1.0
  static const double temperature = 0.7;         // Higher = more creative
}
```

## 🔧 Advanced Features

### Manual Topic Detection

You can manually trigger topic detection for any tab:

```dart
final topicService = TopicDetectionService();
final newTopic = await topicService.manuallyDetectTopic(tabId);
```

### Reset Analysis

To allow re-analysis of a tab:

```dart
topicService.resetTabAnalysis(tabId);
```

### Clear All Cache

```dart
topicService.clearCache();
```

## 🔄 Fallback Mode (No API Key)

If you don't configure an API key, the system automatically falls back to **rule-based detection**:

- Extracts keywords from messages
- Removes common words
- Uses top 3 keywords as topic name
- Less accurate but works offline

## 🛡️ Security Best Practices

### For Production Apps:

1. **Never commit API keys to Git**
   ```bash
   # Add to .gitignore
   lib/config/ai_config.dart
   ```

2. **Use Environment Variables**
   ```dart
   static const String geminiApiKey = 
     String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
   ```

3. **Or Use Flutter Secure Storage**
   ```yaml
   dependencies:
     flutter_secure_storage: ^9.0.0
   ```
   
   ```dart
   final storage = FlutterSecureStorage();
   final apiKey = await storage.read(key: 'gemini_api_key');
   ```

4. **Backend Proxy (Recommended)**
   - Store API key on your backend
   - Call your backend from the app
   - Backend calls Gemini API

## 📊 Monitoring & Debugging

### Check if AI is Working

Look for these console messages:

```
✅ AI Topic Detection initialized successfully
✅ Tab renamed to: pets app discussion
```

### If API Key is Not Configured

```
⚠️ Warning: Gemini API key not configured
📝 Get your free API key from: https://makersuite.google.com/app/apikey
```

### Debug Mode

Add this to see detailed logs:

```dart
// In topic_detection_service.dart
print('Analyzing ${messages.length} messages...');
print('Detected topic: $detectedTopic');
```

## 💡 Tips for Best Results

1. **Let users chat naturally** - AI works better with natural conversation
2. **5-10 messages** is optimal for topic detection
3. **Avoid very short messages** (like "ok", "yes") - they don't help detection
4. **Mix of context** - Better results when messages have context

## 🔍 Troubleshooting

### Issue: Tab names not changing

**Solutions:**
- Check if API key is configured correctly
- Ensure at least 5 messages in the tab
- Check console for error messages
- Verify tab name is still default (e.g., "Topic 1")

### Issue: "API key not valid" error

**Solutions:**
- Verify API key is correct
- Check if API key is enabled in Google Cloud Console
- Ensure Gemini API is enabled for your project

### Issue: App crashes on startup

**Solutions:**
- Run `flutter clean && flutter pub get`
- Check if all imports are correct
- Verify Firebase is properly configured

## 📚 API Limits (Free Tier)

Google Gemini Free Tier:
- **60 requests per minute**
- **1,500 requests per day**
- More than enough for a chat app!

For higher limits, use the paid tier.

## 🎨 UI Customization

The tab names update automatically in the UI. No additional changes needed!

To add a visual indicator when AI is analyzing:

```dart
// In chat_screen.dart
if (isAnalyzingTopic) {
  return Row(
    children: [
      Text(tab.tabName),
      SizedBox(width: 4),
      SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    ],
  );
}
```

## 🌐 Alternative AI Providers

Want to use a different AI? Easy!

### OpenAI (ChatGPT)

1. Add dependency:
   ```yaml
   dependencies:
     dart_openai: ^5.1.0
   ```

2. Update `topic_detection_service.dart`:
   ```dart
   final response = await OpenAI.instance.chat.create(
     model: "gpt-3.5-turbo",
     messages: [
       OpenAIChatCompletionChoiceMessageModel(
         content: prompt,
         role: OpenAIChatMessageRole.user,
       ),
     ],
   );
   ```

### Anthropic (Claude)

1. Add HTTP calls to Claude API
2. Similar integration pattern

## 🚀 Future Enhancements

Ideas to extend this feature:

1. **Multi-language support** - Detect topics in any language
2. **Tab suggestions** - Suggest topic names to users
3. **Categorization** - Auto-categorize tabs (work, personal, etc.)
4. **Smart tab merging** - Merge tabs with similar topics
5. **Topic insights** - Show conversation analytics
6. **Custom prompts** - Let users customize AI prompts

## 📞 Support

If you need help:
1. Check this guide first
2. Review error messages in console
3. Test with fallback mode (no API key)
4. Check Gemini API status: [Google Cloud Status](https://status.cloud.google.com/)

## 📄 License & Credits

- **Google Gemini AI** - Google LLC
- **TABS Chat App** - Your Project
- Built with Flutter & Firebase

---

## Quick Reference Card

```
📦 Install:     flutter pub get
🔑 API Key:     lib/config/ai_config.dart
🚀 Run:         flutter run
⚙️ Config:      lib/config/ai_config.dart
📊 Logs:        Check console for ✅ messages
🐛 Debug:       Look for ⚠️ warnings
```

---

**Congratulations!** Your chat app now has intelligent, AI-powered tab naming! 🎉

