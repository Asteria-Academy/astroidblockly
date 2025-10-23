// lib/services/agentic_ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/agentic_response.dart';
import '../config/app_prompts.dart';
import 'kolosal_api_service.dart';
import 'bluetooth_service.dart';

/// Agentic AI Service that enables the AI to take actions through tool calling
class AgenticAIService {
  final KolosalApiService _apiService;
  final BluetoothService _bluetoothService;

  AgenticAIService({
    required KolosalApiService apiService,
    required BluetoothService bluetoothService,
  })  : _apiService = apiService,
        _bluetoothService = bluetoothService;

  /// Available tools that the AI can use
  static final List<AITool> availableTools = [
    AITool(
      name: 'get_robot_status',
      description: 'Check robot connection status and battery level',
      parameters: {
        'type': 'object',
        'properties': {},
      },
    ),
    AITool(
      name: 'execute_robot_command',
      description: 'Execute a movement command on the connected robot',
      parameters: {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'enum': [
              'move_forward',
              'move_backward',
              'turn_left',
              'turn_right',
              'spin_left',
              'spin_right',
              'stop'
            ],
            'description': 'The command to execute',
          },
          'duration_ms': {
            'type': 'number',
            'description': 'Duration in milliseconds (default: 1000)',
          },
          'speed': {
            'type': 'number',
            'description': 'Speed from 0-255 (default: 100)',
          },
        },
        'required': ['command'],
      },
    ),
    AITool(
      name: 'explain_concept',
      description: 'Provide detailed educational explanation about a robotics concept',
      parameters: {
        'type': 'object',
        'properties': {
          'concept': {
            'type': 'string',
            'description': 'The robotics concept to explain',
          },
        },
        'required': ['concept'],
      },
    ),
    AITool(
      name: 'stop_robot',
      description: 'Emergency stop - immediately halt all robot movement',
      parameters: {
        'type': 'object',
        'properties': {},
      },
    ),
  ];

  /// Main method to process user message with agentic capabilities
  Future<AgenticResponse> processMessage(
    String userMessage,
    List<ChatMessage> conversationHistory,
  ) async {
    try {
      // Build context with agentic system prompt
      final List<ChatMessage> contextWithPrompt = [
        ChatMessage(
          text: AppPrompts.agenticSystemPrompt,
          role: ChatRole.system,
        ),
        ...conversationHistory,
      ];

      // Get AI response
      final String aiResponse = await _apiService.getChatCompletion(
        contextWithPrompt,
      );

      if (aiResponse.isEmpty) {
        return AgenticResponse(
          message: "Sorry, I couldn't process that. Could you try again?",
        );
      }

      // Try to parse as tool call
      final toolCallResult = _parseToolCall(aiResponse);

      if (toolCallResult != null) {
        // It's a tool call - execute it
        final executedToolCall = await _executeTool(toolCallResult);

        // Get the message from the tool call or create a default one
        String responseMessage = toolCallResult.arguments['message']?.toString() ??
            'Processing...';

        // If tool execution failed, append error info
        if (!executedToolCall.success) {
          responseMessage += '\n\n⚠️ ${executedToolCall.errorMessage}';
        } else if (executedToolCall.result.isNotEmpty) {
          // For status checks, append the result
          if (executedToolCall.toolName == 'get_robot_status') {
            responseMessage = _formatRobotStatus(executedToolCall.result);
          } else if (executedToolCall.toolName == 'explain_concept') {
            responseMessage = executedToolCall.result;
          }
        }

        return AgenticResponse(
          message: responseMessage,
          toolCalls: [executedToolCall],
          requiresConfirmation: false,
        );
      } else {
        // Normal text response
        return AgenticResponse(
          message: aiResponse,
        );
      }
    } catch (e) {
      debugPrint('AgenticAIService error: $e');
      return AgenticResponse(
        message: "Sorry, I encountered an error. Please try again.",
      );
    }
  }

  /// Parse AI response to detect tool calls
  ToolCall? _parseToolCall(String response) {
    try {
      // Remove any markdown code blocks
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll('```', '').trim();
      }

      // Try to parse as JSON
      final json = jsonDecode(cleaned);

      if (json is Map<String, dynamic> && json.containsKey('tool')) {
        return ToolCall.fromJson(json);
      }
    } catch (e) {
      // Not a tool call, just normal text
      debugPrint('Not a tool call, treating as normal response');
    }
    return null;
  }

  /// Execute a tool and return the result
  Future<ToolCall> _executeTool(ToolCall toolCall) async {
    try {
      switch (toolCall.toolName) {
        case 'get_robot_status':
          final result = await _getRobotStatus();
          return toolCall.copyWith(result: result, success: true);

        case 'execute_robot_command':
          final result = await _executeRobotCommand(toolCall.arguments);
          return toolCall.copyWith(
            result: result,
            success: !result.startsWith('ERROR'),
          );

        case 'explain_concept':
          final result = await _explainConcept(toolCall.arguments);
          return toolCall.copyWith(result: result, success: true);

        case 'stop_robot':
          final result = await _stopRobot();
          return toolCall.copyWith(result: result, success: true);

        default:
          return toolCall.copyWith(
            result: 'Unknown tool',
            success: false,
            errorMessage: 'Tool not found: ${toolCall.toolName}',
          );
      }
    } catch (e) {
      debugPrint('Tool execution error: $e');
      return toolCall.copyWith(
        result: '',
        success: false,
        errorMessage: 'Error executing tool: $e',
      );
    }
  }

  /// Tool: Get robot connection status and battery level
  Future<String> _getRobotStatus() async {
    return jsonEncode({
      'connected': _bluetoothService.isConnected,
      'battery_level': _bluetoothService.batteryLevel,
      'device_name': _bluetoothService.connectedDevice?.platformName ?? 'None',
      'state': _bluetoothService.sequencerState.toString().split('.').last,
    });
  }

  /// Tool: Execute a robot command
  Future<String> _executeRobotCommand(Map<String, dynamic> args) async {
    // Check connection first
    if (!_bluetoothService.isConnected) {
      return 'ERROR: Robot not connected. Please connect your robot first.';
    }

    // Check if robot is already running
    if (_bluetoothService.sequencerState == SequencerState.running) {
      return 'ERROR: Robot is already executing a command. Please wait.';
    }

    try {
      final String command = args['command'] as String;
      final int durationMs = args['duration_ms'] as int? ?? 1000;
      final int speed = args['speed'] as int? ?? 100;

      // Validate speed
      if (speed < 0 || speed > 255) {
        return 'ERROR: Speed must be between 0 and 255';
      }

      // Calculate left and right speeds based on command
      final speeds = _calculateMotorSpeeds(command, speed);
      final int leftSpeed = speeds['left']!;
      final int rightSpeed = speeds['right']!;

      // Build command JSON
      final Map<String, dynamic> commandJson = {
        'command': 'DRIVE_DIRECT',
        'params': {
          'duration_ms': durationMs,
          'left_speed': leftSpeed,
          'right_speed': rightSpeed,
        },
      };

      // Execute command
      await _bluetoothService.runCommandSequence(jsonEncode([commandJson]));

      return 'SUCCESS: Command executed';
    } catch (e) {
      return 'ERROR: Failed to execute command - $e';
    }
  }

  /// Tool: Explain a robotics concept
  Future<String> _explainConcept(Map<String, dynamic> args) async {
    final String concept = args['concept'] as String? ?? 'robotics';

    try {
      // Create educational prompt
      final educationalPrompt = """
Explain this robotics concept to a beginner student: "$concept"

Requirements:
- Use simple, friendly language
- Include real-world examples
- Add analogies to help understanding
- Keep it concise (3-4 paragraphs max)
- Encourage hands-on experimentation
- Make it fun and engaging!

Focus on practical understanding, not just theory.
""";

      // Get explanation from AI
      final response = await _apiService.getChatCompletion([
        ChatMessage(text: educationalPrompt, role: ChatRole.system),
      ]);

      if (response.isEmpty) {
        return 'I couldn\'t generate an explanation. Please try again.';
      }

      return response;
    } catch (e) {
      return 'Error generating explanation: $e';
    }
  }

  /// Tool: Stop robot immediately
  Future<String> _stopRobot() async {
    if (!_bluetoothService.isConnected) {
      return 'ERROR: Robot not connected';
    }

    try {
      _bluetoothService.stopSequence();
      return 'SUCCESS: Robot stopped';
    } catch (e) {
      return 'ERROR: Failed to stop robot - $e';
    }
  }

  /// Map high-level commands to motor speeds for differential drive
  Map<String, int> _calculateMotorSpeeds(String command, int baseSpeed) {
    switch (command.toLowerCase()) {
      case 'move_forward':
      case 'forward':
      case 'maju':
        // Both motors forward at same speed
        return {'left': baseSpeed, 'right': baseSpeed};

      case 'move_backward':
      case 'backward':
      case 'mundur':
        // Both motors backward at same speed (negative)
        return {'left': -baseSpeed, 'right': -baseSpeed};

      case 'turn_left':
      case 'left':
      case 'kiri':
        // Left motor slower/stopped, right motor forward
        // For sharper turn, left can be negative
        return {'left': 0, 'right': baseSpeed};

      case 'turn_right':
      case 'right':
      case 'kanan':
        // Right motor slower/stopped, left motor forward
        return {'left': baseSpeed, 'right': 0};

      case 'spin_left':
      case 'rotate_left':
      case 'putar_kiri':
        // Left motor backward, right motor forward (spin in place)
        return {'left': -baseSpeed, 'right': baseSpeed};

      case 'spin_right':
      case 'rotate_right':
      case 'putar_kanan':
        // Left motor forward, right motor backward (spin in place)
        return {'left': baseSpeed, 'right': -baseSpeed};

      case 'stop':
      case 'berhenti':
        // Both motors stop
        return {'left': 0, 'right': 0};

      default:
        // Default to forward
        debugPrint('Unknown command: $command, defaulting to forward');
        return {'left': baseSpeed, 'right': baseSpeed};
    }
  }

  /// Format robot status into user-friendly message
  String _formatRobotStatus(String jsonStatus) {
    try {
      final status = jsonDecode(jsonStatus);
      final bool connected = status['connected'] as bool;
      final int battery = status['battery_level'] as int;
      final String deviceName = status['device_name'] as String;
      final String state = status['state'] as String;

      if (!connected) {
        return "🤖 Robot Status: Not Connected\n\nYour robot isn't connected yet. Tap the CONNECT button to find and connect to your robot!";
      }

      String batteryEmoji = '🔋';
      if (battery < 20) {
        batteryEmoji = '🪫';
      } else if (battery > 80) {
        batteryEmoji = '⚡';
      }

      String stateEmoji = state == 'running' ? '▶️' : '⏸️';

      return "🤖 Robot Status: Connected\n\n"
          "Device: $deviceName\n"
          "$batteryEmoji Battery: ${battery >= 0 ? '$battery%' : 'Unknown'}\n"
          "$stateEmoji State: ${state == 'running' ? 'Running' : 'Idle'}\n\n"
          "Your robot is ready to go! 🚀";
    } catch (e) {
      return "Could not parse robot status.";
    }
  }
}
