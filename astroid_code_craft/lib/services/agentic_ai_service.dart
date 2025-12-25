// lib/services/agentic_ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/agentic_response.dart';
import '../config/app_prompts.dart';
import 'kolosal_api_service.dart';
import 'bluetooth_service.dart';
import 'workspace_bridge_service.dart';

/// Agentic AI Service that enables the AI to take actions through tool calling
class AgenticAIService {
  final KolosalApiService _apiService;
  final BluetoothService _bluetoothService;
  final List<String> _pendingCommandSequences = [];
  bool _isProcessingQueue = false;
  static const int _maxQueueSize = 5; // avoid unbounded backlog

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
      name: 'set_led_color',
      description: 'Change an individual LED segment or all LEDs',
      parameters: {
        'type': 'object',
        'properties': {
          'led_id': {
            'type': 'string',
            'description': 'LED id 1-12 or "all"',
          },
          'r': {
            'type': 'number',
            'description': 'Red value 0-255',
          },
          'g': {
            'type': 'number',
            'description': 'Green value 0-255',
          },
          'b': {
            'type': 'number',
            'description': 'Blue value 0-255',
          },
        },
        'required': ['led_id', 'r', 'g', 'b'],
      },
    ),
    AITool(
      name: 'display_icon',
      description: 'Show an expression icon (happy, sad, confused, mad)',
      parameters: {
        'type': 'object',
        'properties': {
          'icon_name': {
            'type': 'string',
            'enum': ['happy', 'sad', 'confused', 'mad'],
          },
        },
        'required': ['icon_name'],
      },
    ),
    AITool(
      name: 'set_head_position',
      description: 'Adjust the robot head pitch/yaw',
      parameters: {
        'type': 'object',
        'properties': {
          'pitch': {
            'type': 'number',
            'description': 'Pitch degrees (e.g., 80-100)',
          },
          'yaw': {
            'type': 'number',
            'description': 'Yaw degrees (e.g., 80-100)',
          },
        },
        'required': ['pitch', 'yaw'],
      },
    ),
    AITool(
      name: 'play_sound',
      description: 'Play a built-in robot sound',
      parameters: {
        'type': 'object',
        'properties': {
          'sound_id': {
            'type': 'number',
            'description': 'Sound id (1-4)',
          },
        },
        'required': ['sound_id'],
      },
    ),
    AITool(
      name: 'get_workspace_json',
      description: 'Retrieve the current Blockly workspace as JSON',
      parameters: {
        'type': 'object',
        'properties': {},
      },
    ),
    AITool(
      name: 'set_workspace_json',
      description: 'Load a Blockly workspace from serialized JSON',
      parameters: {
        'type': 'object',
        'properties': {
          'workspace_json': {
            'type': 'string',
            'description': 'Serialized workspace JSON string',
          },
        },
        'required': ['workspace_json'],
      },
    ),
    AITool(
      name: 'run_workspace',
      description: 'Run the code generated from the current workspace',
      parameters: {
        'type': 'object',
        'properties': {},
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

        // Use the AI-supplied message when available
        String responseMessage =
            toolCallResult.message ?? toolCallResult.arguments['message']?.toString() ?? 'Processing...';

        // If tool execution failed, append error info
        if (!executedToolCall.success) {
          responseMessage += '\n\n ${executedToolCall.errorMessage}';
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

        case 'set_led_color':
          final ledId = toolCall.arguments['led_id'] ?? 'all';
          final int red = (toolCall.arguments['r'] as num?)?.toInt().clamp(0, 255) ?? 0;
          final int green = (toolCall.arguments['g'] as num?)?.toInt().clamp(0, 255) ?? 0;
          final int blue = (toolCall.arguments['b'] as num?)?.toInt().clamp(0, 255) ?? 0;
          final command = {
            'command': 'SET_LED_COLOR',
            'params': {
              'led_id': ledId,
              'r': red,
              'g': green,
              'b': blue,
            },
          };
          final result = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(result: result, success: !result.startsWith('ERROR'));

        case 'display_icon':
          final iconName = (toolCall.arguments['icon_name'] as String?) ?? 'happy';
          final command = {
            'command': 'DISPLAY_ICON',
            'params': {'icon_name': iconName},
          };
          final iconResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(result: iconResult, success: !iconResult.startsWith('ERROR'));

        case 'set_head_position':
          final pitch = (toolCall.arguments['pitch'] as num?)?.toInt().clamp(80, 100) ?? 90;
          final yaw = (toolCall.arguments['yaw'] as num?)?.toInt().clamp(80, 100) ?? 90;
          final command = {
            'command': 'SET_HEAD_POSITION',
            'params': {'pitch': pitch, 'yaw': yaw},
          };
          final headResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(result: headResult, success: !headResult.startsWith('ERROR'));

        case 'play_sound':
          final soundId = (toolCall.arguments['sound_id'] as num?)?.toInt().clamp(1, 4) ?? 1;
          final command = {
            'command': 'PLAY_INTERNAL_SOUND',
            'params': {'sound_id': soundId},
          };
          final soundResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(result: soundResult, success: !soundResult.startsWith('ERROR'));

        case 'get_workspace_json':
          final workspaceJson = await WorkspaceBridgeService.instance.exportWorkspaceJson();
          if (workspaceJson == null || workspaceJson.isEmpty) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage: 'Workspace bridge unavailable. Please open the Blockly screen.',
            );
          }
          return toolCall.copyWith(result: workspaceJson, success: true);

        case 'set_workspace_json':
          String? workspaceJson = toolCall.arguments['workspace_json'] as String?;
          if (workspaceJson == null) {
            final alt = toolCall.arguments['workspace'] ?? toolCall.arguments['workspaceJson'];
            if (alt != null) {
              workspaceJson = alt is String ? alt : jsonEncode(alt);
            }
          }
          if (workspaceJson == null) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage: 'Workspace JSON missing.',
            );
          }
          final applied =
              await WorkspaceBridgeService.instance.applyWorkspaceJson(workspaceJson);
          if (!applied) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage: 'Failed to load workspace. Make sure the webview is open.',
            );
          }
          return toolCall.copyWith(result: 'Workspace loaded', success: true);

        case 'run_workspace':
          final commandJson = await WorkspaceBridgeService.instance.exportCommandJson();
          if (commandJson == null || commandJson.trim().isEmpty) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage: 'Workspace unavailable. Please open the Blockly screen.',
            );
          }
          if (commandJson.trim() == '[]') {
            return toolCall.copyWith(
              result: 'Workspace has no executable commands.',
              success: true,
            );
          }
          final runResult = await _runOrQueueSequence(commandJson);
          return toolCall.copyWith(
            result: runResult,
            success: !runResult.startsWith('ERROR'),
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

    try {
      // Option B: explicit sequencer commands array
      if (args['commands'] is List) {
        final List<dynamic> rawCommands = args['commands'] as List<dynamic>;
        if (rawCommands.isEmpty) {
          return 'ERROR: No commands provided.';
        }

        // Validate structure
        final List<Map<String, dynamic>> sequencerCommands = [];
        bool hasInfiniteLoop = false;
        for (final item in rawCommands) {
          if (item is! Map<String, dynamic>) {
            return 'ERROR: Each command must be an object.';
          }
          if (!item.containsKey('command')) {
            return 'ERROR: Command object missing "command" field.';
          }
          final commandName = (item['command'] as String).toUpperCase();
          if (commandName == 'META_START_INFINITE_LOOP') {
            hasInfiniteLoop = true;
          }
          // Optional safety: clamp speeds if present
          final params = item['params'];
          Map<String, dynamic> safeParams;
          if (params is Map<String, dynamic>) {
            safeParams = Map<String, dynamic>.from(params);
            if (params.containsKey('left_speed')) {
              final int ls = (params['left_speed'] as num).toInt();
              safeParams['left_speed'] = ls.clamp(-255, 255);
            }
            if (params.containsKey('right_speed')) {
              final int rs = (params['right_speed'] as num).toInt();
              safeParams['right_speed'] = rs.clamp(-255, 255);
            }
          } else {
            safeParams = {};
          }
          // Provide default duration for motion commands if missing
          if (item['command'] == 'DRIVE_DIRECT' && !safeParams.containsKey('duration_ms')) {
            safeParams['duration_ms'] = 1000;
          }
          item['params'] = safeParams;
          sequencerCommands.add(item);
        }

        final sequenceJson = jsonEncode(sequencerCommands);
        final executionResult = await _runOrQueueSequence(sequenceJson);
        if (hasInfiniteLoop) {
          return '$executionResult\n\nNOTE: This sequence contains an infinite loop. Use the stop button or the "stop_robot" tool to cancel it when needed.';
        }
        return executionResult;
      }

      // Option A: single high-level command -> map to DRIVE_DIRECT
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

      // Execute command (or queue if busy)
      return await _runOrQueueSequence(jsonEncode([commandJson]));
    } catch (e) {
      return 'ERROR: Failed to execute command - $e';
    }
  }

  /// Runs a command sequence immediately if idle, otherwise enqueues it.
  Future<String> _runOrQueueSequence(String commandJsonArray) async {
    // If sequencer busy, enqueue and process later
    if (_bluetoothService.sequencerState == SequencerState.running) {
      if (_pendingCommandSequences.length >= _maxQueueSize) {
        return 'ERROR: Command queue is full. Please wait and try again.';
      }
      _pendingCommandSequences.add(commandJsonArray);
      _processCommandQueue();
      return 'QUEUED: Robot is busy. Your command will run next.';
    }

    try {
      await _bluetoothService.runCommandSequence(commandJsonArray);
    } catch (e) {
      return 'ERROR: Failed to start command - $e';
    }

    // Kick off any pending items after this one finishes
    _processCommandQueue();
    return 'SUCCESS: Command executed';
  }

  /// Simple FIFO queue processor that waits for the sequencer to be idle before dispatching.
  void _processCommandQueue() {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    () async {
      while (_pendingCommandSequences.isNotEmpty) {
        // Wait until sequencer is idle
        while (_bluetoothService.sequencerState == SequencerState.running) {
          await Future.delayed(const Duration(milliseconds: 150));
        }

        // If disconnected, drop remaining queue
        if (!_bluetoothService.isConnected) {
          _pendingCommandSequences.clear();
          break;
        }

        final next = _pendingCommandSequences.removeAt(0);
        await _bluetoothService.runCommandSequence(next);
      }
      _isProcessingQueue = false;
    }();
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
      // Clear any queued commands and stop current sequence
      _pendingCommandSequences.clear();
      _bluetoothService.stopSequence();
      return 'SUCCESS: Robot stopped and queue cleared';
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
