# 🤖 Agentic AI Implementation - Usage Guide

## ✅ Implementation Complete!

The Agentic AI system has been successfully integrated into your Astroid CodeCraft application. This document explains how to use and test the new capabilities.

---

## 📁 Files Created/Modified

### **New Files:**
1. `lib/models/agentic_response.dart` - Response models for tool calling
2. `lib/services/agentic_ai_service.dart` - Main agentic AI service (400+ lines)

### **Modified Files:**
1. `lib/config/app_prompts.dart` - Added enhanced agentic system prompt
2. `lib/screens/code_chat_screen.dart` - Integrated agentic service

---

## 🎯 New Capabilities

Your AI chatbot can now:

### **1. Check Robot Status** 🤖
```
User: "Is my robot connected?"
User: "Check battery"
User: "Robot status?"
```
**What happens:**
- AI calls `get_robot_status` tool
- Returns connection status, battery level, device name, and state
- Formatted with emojis for better UX

### **2. Execute Robot Commands** ⚡
```
User: "Move forward for 2 seconds"
User: "Turn left"
User: "Make robot go backward"
User: "Stop the robot"
```
**What happens:**
- AI parses the command and parameters
- Validates robot connection
- Executes command via Bluetooth
- Confirms execution to user

**Supported Commands:**
- `move_forward` / `forward`
- `move_backward` / `backward`
- `turn_left` / `left`
- `turn_right` / `right`
- `stop`

**Parameters:**
- `duration_ms`: How long (default: 1000ms)
- `speed`: Motor speed 0-255 (default: 100)

### **3. Explain Robotics Concepts** 📚
```
User: "What is a servo motor?"
User: "Explain PWM"
User: "How do sensors work?"
```
**What happens:**
- AI calls `explain_concept` tool
- Generates educational explanation
- Uses simple language with analogies
- Encourages hands-on experimentation

### **4. Emergency Stop** 🛑
```
User: "Stop!"
User: "Stop robot!"
User: "Emergency stop"
```
**What happens:**
- Immediately halts robot movement
- Works even if robot is running a sequence

---

## 🧪 Testing Guide

### **Test 1: Basic Conversation**
```
You: "Hello!"
Expected: Normal greeting response (no tool call)
```

### **Test 2: Robot Status (Not Connected)**
```
You: "Is robot connected?"
Expected: Tool call → Status message saying not connected
```

### **Test 3: Robot Status (Connected)**
**Prerequisites:** Connect your robot first via CONNECT screen

```
You: "Check my robot status"
Expected: 
🤖 Robot Status: Connected

Device: [Robot Name]
🔋 Battery: XX%
⏸️ State: Idle

Your robot is ready to go! 🚀
```

### **Test 4: Execute Command (Not Connected)**
```
You: "Move forward 2 seconds"
Expected: Error message about robot not connected
```

### **Test 5: Execute Command (Connected)**
**Prerequisites:** Robot must be connected

```
You: "Make robot move forward for 3 seconds"
Expected: 
- AI confirms: "Moving your robot forward for 3 seconds!"
- Robot actually moves!
- Response: Command executed successfully
```

### **Test 6: Explanation**
```
You: "What is a servo motor?"
Expected: Detailed educational explanation with:
- Simple language
- Real-world examples
- Analogies
- Encouragement to experiment
```

### **Test 7: Multi-turn Conversation**
```
You: "Is robot connected?"
AI: [Status check...]
You: "Good, make it move forward"
AI: [Executes command...]
You: "Now turn left"
AI: [Executes command...]
```

### **Test 8: Voice Commands**
**Prerequisites:** Microphone permission granted

1. Tap microphone icon
2. Say: "Is robot connected?"
3. Expected: Same as text input

---

## 🔧 How It Works

### **Architecture Flow:**

```
User Input (Text/Voice)
    ↓
CodeChatScreen
    ↓
AgenticAIService.processMessage()
    ↓
Kolosal AI (with enhanced prompt)
    ↓
Response Parser (JSON detection)
    ↓
    ├─→ Tool Call Detected?
    │       ↓
    │   Execute Tool
    │   (BluetoothService interaction)
    │       ↓
    │   Format Response
    │       ↓
    └─→ Normal Text Response
        ↓
Display to User
```

### **Tool Calling Mechanism:**

The AI is instructed to respond with JSON when it needs to use a tool:

```json
{
  "tool": "execute_robot_command",
  "args": {
    "command": "move_forward",
    "duration_ms": 2000,
    "speed": 100
  },
  "message": "Moving your robot forward for 2 seconds!"
}
```

The `AgenticAIService` parses this JSON and executes the corresponding function.

---

## ⚙️ Configuration

### **Available Tools** (in `AgenticAIService`):

```dart
static final List<AITool> availableTools = [
  AITool(name: 'get_robot_status', ...),
  AITool(name: 'execute_robot_command', ...),
  AITool(name: 'explain_concept', ...),
  AITool(name: 'stop_robot', ...),
];
```

### **System Prompt** (in `AppPrompts.agenticSystemPrompt`):
- Instructs AI on available tools
- Defines JSON response format
- Sets safety rules
- Provides examples

---

## 🐛 Troubleshooting

### **Issue: AI doesn't call tools**
**Cause:** Kolosal AI might not follow JSON format strictly
**Solution:** Check response in debug console, adjust prompt if needed

### **Issue: Robot doesn't move**
**Possible causes:**
1. Robot not connected → Check connection
2. Robot already running → Wait for completion
3. Invalid command format → Check logs

### **Issue: Battery shows -1**
**Cause:** Battery info not received yet
**Solution:** Wait a few seconds, robot sends battery every 10s

### **Issue: Tool execution fails**
**Check:**
1. Console logs for error messages
2. Bluetooth connection status
3. Robot is powered on

---

## 🎨 UI/UX Features

### **Visual Feedback:**
- 💬 Chat bubbles (user vs AI)
- 🎤 Voice input indicator
- ⏳ Typing indicator while AI processes
- 🎨 Color-coded messages (blue for user, dark for AI)

### **Safety Features:**
- ✅ Connection check before execution
- ✅ Speed validation (0-255)
- ✅ State check (prevent double execution)
- ✅ Error messages for invalid operations

---

## 🚀 Next Steps (Future Enhancements)

### **Phase 2: Code Integration**
- [ ] Read/edit Blockly code
- [ ] Generate code from natural language
- [ ] Code debugging assistance

### **Phase 3: Advanced Features**
- [ ] Command sequences (multiple steps)
- [ ] Conditional logic
- [ ] Loop generation
- [ ] Visual code preview

### **Phase 4: Polish**
- [ ] Confirmation dialogs for dangerous ops
- [ ] Animation feedback
- [ ] Voice command shortcuts
- [ ] Tutorial mode

---

## 📊 Command Examples

### **Simple Commands:**
```
"move forward"          → 1 second, speed 100
"go backward 3 seconds" → 3 seconds, speed 100
"turn left"             → 1 second, speed 100
"stop"                  → immediate stop
```

### **Advanced Commands:**
```
"move forward fast"     → AI interprets "fast" as higher speed
"turn left slowly"      → AI interprets "slowly" as lower speed
"move backward 5 seconds at speed 150" → Explicit parameters
```

### **Status Queries:**
```
"status"
"battery?"
"is connected?"
"check robot"
```

### **Educational:**
```
"what is [concept]?"
"explain [topic]"
"how does [thing] work?"
"teach me about [subject]"
```

---

## 🔐 Safety Considerations

### **Built-in Safety:**
1. **Connection Check:** Commands only execute if robot connected
2. **Speed Limits:** Speed capped at 0-255
3. **State Check:** Prevents concurrent execution
4. **Error Handling:** Graceful failure with user feedback

### **User Responsibility:**
- Ensure robot has clear space to move
- Monitor robot during execution
- Use emergency stop if needed
- Keep speed reasonable for beginners

---

## 📝 Code Reference

### **Add New Tool:**

1. Define tool in `AgenticAIService.availableTools`
2. Add case in `_executeTool()` switch
3. Implement handler method (e.g., `_myNewTool()`)
4. Update system prompt with tool description

Example:
```dart
// 1. Define
AITool(
  name: 'my_new_tool',
  description: 'Does something cool',
  parameters: {...},
)

// 2. Add case
case 'my_new_tool':
  final result = await _myNewTool(toolCall.arguments);
  return toolCall.copyWith(result: result, success: true);

// 3. Implement
Future<String> _myNewTool(Map<String, dynamic> args) async {
  // Your logic here
  return 'Success';
}
```

---

## 📞 Support

If you encounter issues:

1. **Check Console Logs:** Look for error messages
2. **Verify Connection:** Ensure robot is connected
3. **Test Kolosal API:** Make sure API key is valid
4. **Review Prompt:** Check if AI response is valid JSON

**Debug Mode:**
Set `debugPrint` statements to see:
- Tool call detection
- Execution results
- Bluetooth communication

---

## ✅ Success Criteria

Your implementation is working if:
- ✅ AI responds to normal questions
- ✅ AI detects when to use tools
- ✅ Robot status check returns correct info
- ✅ Commands make robot move
- ✅ Explanations are educational
- ✅ Error handling is graceful

---

## 🎉 Congratulations!

You now have a working Agentic AI assistant that can:
- Have conversations
- Check robot status
- Control robot movements
- Teach robotics concepts
- Handle errors gracefully

**Ready to test? Connect your robot and start chatting!** 🚀🤖

---

Last Updated: October 23, 2025
Version: 1.0.0 (Phase 1 - Foundation)
