# 🚀 Quick Start - AI Topic Detection

## 3 Steps to Enable AI-Powered Tab Naming

### 1️⃣ Get API Key (2 minutes)
Visit: https://makersuite.google.com/app/apikey
- Sign in with Google
- Click "Create API Key"
- Copy the key

### 2️⃣ Add API Key (1 minute)
Open: `lib/config/ai_config.dart`

Change this:
```dart
static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

To this:
```dart
static const String geminiApiKey = 'AIzaSyD...your-actual-key...';
```

### 3️⃣ Run App (1 minute)
```bash
flutter run
```

## ✅ That's It!

Now when users chat:
- After **5 messages** in a tab
- AI automatically detects the topic
- Tab renames from "Topic 1" → "pets app discussion"

## 🧪 Test It

1. Create a new conversation
2. Chat about a specific topic (e.g., "Let's plan the pet app features")
3. Send 5-6 messages
4. Watch the tab name update automatically!

## 📖 Full Guide

See `AI_TOPIC_DETECTION_GUIDE.md` for complete documentation.

## ⚡ Works Without API Key Too!

If you skip the API key setup, the app uses keyword-based detection (less accurate but works offline).

---

**Need Help?** Check console logs for:
- ✅ = Working
- ⚠️ = Need to configure

