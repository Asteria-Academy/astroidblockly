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

  // Simple queue for robot command sequences to avoid overlapping runs
  final List<String> _pendingCommandSequences = [];
  static const int _maxQueueSize = 10;
  bool _isProcessingQueue = false;

  AgenticAIService({
    required KolosalApiService apiService,
    required BluetoothService bluetoothService,
  }) : _apiService = apiService,
       _bluetoothService = bluetoothService;

  /// Available tools that the AI can use
  static final List<AITool> availableTools = [
    AITool(
      name: 'get_robot_status',
      description: 'Check robot connection status and battery level',
      parameters: {'type': 'object', 'properties': {}},
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
              'stop',
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
          'led_id': {'type': 'string', 'description': 'LED id 1-12 or "all"'},
          'r': {'type': 'number', 'description': 'Red value 0-255'},
          'g': {'type': 'number', 'description': 'Green value 0-255'},
          'b': {'type': 'number', 'description': 'Blue value 0-255'},
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
          'sound_id': {'type': 'number', 'description': 'Sound id (1-4)'},
        },
        'required': ['sound_id'],
      },
    ),
    AITool(
      name: 'get_workspace_json',
      description: 'Retrieve the current Blockly workspace as JSON',
      parameters: {'type': 'object', 'properties': {}},
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
      parameters: {'type': 'object', 'properties': {}},
    ),
    AITool(
      name: 'explain_concept',
      description:
          'Provide detailed educational explanation about a robotics concept',
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
      parameters: {'type': 'object', 'properties': {}},
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

      // Try to parse as tool call(s)
      final List<ToolCall> toolCallResults = _parseToolCalls(aiResponse);

      if (toolCallResults.isNotEmpty) {
        // --- GUARDRAIL: Removed Queue Limit ---
        // We now batch commands into a single JSON sequence if possible.

        final List<ToolCall> executedToolCalls = [];
        final List<String> responseSegments = [];
        final List<Map<String, dynamic>> hardwareCommandBatch = [];
        int nonHardwareToolCount = 0;

        // 1. First Pass: Collect hardware commands and count others
        for (final toolCall in toolCallResults) {
          final cmds = await _buildHardwareCommands(toolCall);
          if (cmds != null) {
            hardwareCommandBatch.addAll(cmds);
          } else {
            nonHardwareToolCount++;
          }
        }

        // 2. Execution Strategy
        if (hardwareCommandBatch.isNotEmpty && nonHardwareToolCount == 0) {
          // OPTION A: Pure hardware sequence -> Send as BATCH
          // This is much faster and cleaner (no individual sleeps in AgenticService)

          // Collect messages from original tool calls for user feedback
          final List<String> originalMessages = [];
          for (final toolCall in toolCallResults) {
            final msg =
                toolCall.message ??
                toolCall.arguments['message']?.toString() ??
                '';
            if (msg.trim().isNotEmpty) {
              originalMessages.add(msg.trim());
            }
          }

          final batchToolCall = ToolCall(
            toolName: 'execute_robot_command',
            arguments: {'commands': hardwareCommandBatch},
            result: '',
            message: originalMessages.join('\n'),
          );

          final executedCall = await _executeTool(batchToolCall);

          // Add original tool calls to executedToolCalls for tracking
          executedToolCalls.addAll(
            toolCallResults.map(
              (tc) => tc.copyWith(
                success: executedCall.success,
                result: 'Executed as batch',
              ),
            ),
          );

          // Use original messages for user-friendly response
          if (originalMessages.isNotEmpty) {
            responseSegments.addAll(originalMessages);
          } else {
            // Fallback to batch execution result
            final toolMessage = _buildToolResponseMessage(
              executedCall,
              batchToolCall,
            );
            if (toolMessage.trim().isNotEmpty) {
              responseSegments.add(toolMessage.trim());
            }
          }
        } else {
          // OPTION B: Mixed commands -> Execute Sequentially (Fallback)
          // If we have "Explain concept" mixed with "Move", we run them one by one.
          for (final toolCall in toolCallResults) {
            final executedCall = await _executeTool(toolCall);
            executedToolCalls.add(executedCall);

            final toolMessage = _buildToolResponseMessage(
              executedCall,
              toolCall,
            );
            if (toolMessage.trim().isNotEmpty) {
              responseSegments.add(toolMessage.trim());
            }
          }
        }

        final combinedMessage = responseSegments.join('\n\n');
        return AgenticResponse(
          message: combinedMessage.isEmpty ? 'Processing...' : combinedMessage,
          toolCalls: executedToolCalls,
          requiresConfirmation: false,
        );
      } else {
        // Normal text response
        return AgenticResponse(message: aiResponse);
      }
    } catch (e) {
      debugPrint('AgenticAIService error: $e');
      return AgenticResponse(
        message: "Sorry, I encountered an error. Please try again.",
      );
    }
  }

  /// Parse AI response to detect tool calls
  List<ToolCall> _parseToolCalls(String response) {
    final cleaned = _stripCodeBlocks(response);
    final List<ToolCall> calls = [];

    try {
      final json = jsonDecode(cleaned);
      if (json is Map<String, dynamic> && json.containsKey('tool')) {
        calls.add(ToolCall.fromJson(json));
        return calls;
      }
      if (json is List) {
        for (final item in json) {
          if (item is Map<String, dynamic> && item.containsKey('tool')) {
            calls.add(ToolCall.fromJson(item));
          }
        }
        return calls;
      }
    } catch (_) {
      debugPrint('Not a single JSON block, trying to split');
    }

    for (final chunk in _splitJsonChunks(cleaned)) {
      try {
        final json = jsonDecode(chunk);
        if (json is Map<String, dynamic> && json.containsKey('tool')) {
          calls.add(ToolCall.fromJson(json));
        }
      } catch (_) {
        debugPrint('Failed to parse chunk as tool call: $chunk');
      }
    }

    return calls;
  }

  String _stripCodeBlocks(String response) {
    String cleaned = response.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll('```', '').trim();
    }
    return cleaned;
  }

  List<String> _splitJsonChunks(String input) {
    final List<String> chunks = [];
    int braceCount = 0;
    int startIndex = -1;
    bool inString = false;
    bool isEscaped = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (inString) {
        if (char == '\\' && !isEscaped) {
          isEscaped = true;
        } else {
          if (char == '"' && !isEscaped) {
            inString = false;
          }
          isEscaped = false;
        }
      } else {
        if (char == '"') {
          inString = true;
        } else if (char == '{') {
          if (braceCount == 0) startIndex = i;
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          if (braceCount == 0 && startIndex != -1) {
            chunks.add(input.substring(startIndex, i + 1));
            startIndex = -1;
          }
        }
      }
    }
    return chunks;
  }

  String _buildToolResponseMessage(
    ToolCall executedCall,
    ToolCall originalCall,
  ) {
    String responseMessage =
        originalCall.message ??
        originalCall.arguments['message']?.toString() ??
        '';

    if (!executedCall.success) {
      final errorDetails = executedCall.errorMessage ?? 'Tool execution failed';
      responseMessage = responseMessage.isEmpty
          ? errorDetails
          : '$responseMessage\n\n$errorDetails';
    } else if (executedCall.toolName == 'get_robot_status') {
      responseMessage = _formatRobotStatus(executedCall.result);
    } else if (executedCall.toolName == 'explain_concept') {
      responseMessage = executedCall.result.isNotEmpty
          ? executedCall.result
          : responseMessage;
    } else if (executedCall.result.isNotEmpty) {
      responseMessage = executedCall.result;
    }

    return responseMessage;
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
          final int red =
              (toolCall.arguments['r'] as num?)?.toInt().clamp(0, 255) ?? 0;
          final int green =
              (toolCall.arguments['g'] as num?)?.toInt().clamp(0, 255) ?? 0;
          final int blue =
              (toolCall.arguments['b'] as num?)?.toInt().clamp(0, 255) ?? 0;

          // Ensure led_id is int (1-12) or string "all"
          dynamic cleanLedId;
          if (ledId == 'all' || ledId == 'ALL') {
            cleanLedId = 'all';
          } else if (ledId is num) {
            cleanLedId = ledId.toInt().clamp(1, 12);
          } else if (ledId is String) {
            final parsed = int.tryParse(ledId);
            cleanLedId = parsed != null ? parsed.clamp(1, 12) : 'all';
          } else {
            cleanLedId = 'all';
          }

          final command = {
            'command': 'SET_LED_COLOR',
            'params': {'led_id': cleanLedId, 'r': red, 'g': green, 'b': blue},
          };
          final result = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(
            result: result,
            success: !result.startsWith('ERROR'),
          );

        case 'display_icon':
          final iconName =
              (toolCall.arguments['icon_name'] as String?) ?? 'happy';
          final command = {
            'command': 'DISPLAY_ICON',
            'params': {'icon_name': iconName},
          };
          final iconResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(
            result: iconResult,
            success: !iconResult.startsWith('ERROR'),
          );

        case 'set_head_position':
          final pitch =
              (toolCall.arguments['pitch'] as num?)?.toInt().clamp(80, 100) ??
              90;
          final yaw =
              (toolCall.arguments['yaw'] as num?)?.toInt().clamp(80, 100) ?? 90;
          final command = {
            'command': 'SET_HEAD_POSITION',
            'params': {'pitch': pitch, 'yaw': yaw},
          };
          final headResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(
            result: headResult,
            success: !headResult.startsWith('ERROR'),
          );

        case 'play_sound':
          final soundId =
              (toolCall.arguments['sound_id'] as num?)?.toInt().clamp(1, 4) ??
              1;
          final command = {
            'command': 'PLAY_INTERNAL_SOUND',
            'params': {'sound_id': soundId},
          };
          final soundResult = await _runOrQueueSequence(jsonEncode([command]));
          return toolCall.copyWith(
            result: soundResult,
            success: !soundResult.startsWith('ERROR'),
          );

        case 'get_workspace_json':
          final workspaceJson = await WorkspaceBridgeService.instance
              .exportWorkspaceJson();
          if (workspaceJson == null || workspaceJson.isEmpty) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage:
                  'Workspace unavailable. Please open the Blockly screen.',
            );
          }

          // Check if workspace has only the start block (minimal/empty state)
          try {
            final parsed = jsonDecode(workspaceJson);
            if (parsed is Map && parsed.containsKey('blocks')) {
              final blocks = parsed['blocks'];
              if (blocks is Map && blocks.containsKey('blocks')) {
                final blockList = blocks['blocks'];
                if (blockList is List) {
                  // Check if only program_start block exists
                  if (blockList.length == 1 &&
                      blockList[0] is Map &&
                      blockList[0]['type'] == 'program_start' &&
                      blockList[0]['next'] == null) {
                    return toolCall.copyWith(
                      result: workspaceJson,
                      success: true,
                      // Note: Workspace has only the start block (ready for new blocks)
                    );
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Failed to parse workspace JSON: $e');
          }

          return toolCall.copyWith(result: workspaceJson, success: true);

        case 'set_workspace_json':
          // Check if webview is connected first
          if (!WorkspaceBridgeService.instance.isConnected) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage:
                  'Blockly editor not available. Please open the Blockly screen first.',
            );
          }

          String? workspaceJson =
              toolCall.arguments['workspace_json'] as String?;
          if (workspaceJson == null) {
            final alt =
                toolCall.arguments['workspace'] ??
                toolCall.arguments['workspaceJson'];
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

          final applied = await WorkspaceBridgeService.instance
              .applyWorkspaceJson(workspaceJson);
          if (!applied) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage:
                  'Failed to load workspace. The workspace data may be invalid.',
            );
          }
          return toolCall.copyWith(
            result: 'Workspace loaded successfully!',
            success: true,
          );

        case 'run_workspace':
          final commandJson = await WorkspaceBridgeService.instance
              .exportCommandJson();
          if (commandJson == null || commandJson.trim().isEmpty) {
            return toolCall.copyWith(
              result: '',
              success: false,
              errorMessage:
                  'Workspace unavailable. Please open the Blockly screen.',
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

  /// Helper: Build hardware command list from a ToolCall without executing it
  /// Returns null if the tool is not a hardware command
  Future<List<Map<String, dynamic>>?> _buildHardwareCommands(
    ToolCall toolCall,
  ) async {
    switch (toolCall.toolName) {
      case 'execute_robot_command':
        final args = toolCall.arguments;

        // OPTION B: Explicit commands list (Restored for Looping support)
        if (args['commands'] is List) {
          final List<dynamic> rawCommands = args['commands'] as List<dynamic>;
          final List<Map<String, dynamic>> sequencerCommands = [];
          for (final item in rawCommands) {
            if (item is Map<String, dynamic>) {
              sequencerCommands.add(item);
            }
          }
          return sequencerCommands;
        }

        // OPTION A: Single command
        final String command = args['command'] as String;
        int durationMs = args['duration_ms'] as int? ?? 1000;
        int speed = args['speed'] as int? ?? 100;

        // Guardrails
        if (speed > 100) speed = 100;
        if (speed < 0) speed = 0;
        if (durationMs > 10000) durationMs = 10000;

        Map<String, dynamic>? singleCmd;

        switch (command.toLowerCase()) {
          case 'move_forward':
          case 'forward':
          case 'maju':
            singleCmd = {
              'command': 'MOVE_TIMED',
              'params': {
                'direction': 'forward',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;

          case 'move_backward':
          case 'backward':
          case 'mundur':
            singleCmd = {
              'command': 'MOVE_TIMED',
              'params': {
                'direction': 'backward',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;

          case 'turn_left':
          case 'left':
          case 'belok_kiri':
          case 'kiri':
            singleCmd = {
              'command': 'TURN_TIMED',
              'params': {
                'direction': 'left',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;

          case 'turn_right':
          case 'right':
          case 'belok_kanan':
          case 'kanan':
            singleCmd = {
              'command': 'TURN_TIMED',
              'params': {
                'direction': 'right',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;

          case 'spin_left':
            singleCmd = {
              'command': 'TURN_TIMED',
              'params': {
                'direction': 'left',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;
          case 'spin_right':
            singleCmd = {
              'command': 'TURN_TIMED',
              'params': {
                'direction': 'right',
                'speed': speed,
                'duration_ms': durationMs,
              },
            };
            break;

          case 'stop':
            singleCmd = {
              'command': 'DRIVE_DIRECT',
              'params': {'left_speed': 0, 'right_speed': 0},
            };
            break;
        }

        return singleCmd != null ? [singleCmd] : null;

      case 'set_led_color':
        final ledId = toolCall.arguments['led_id'] ?? 'all';
        final int red =
            (toolCall.arguments['r'] as num?)?.toInt().clamp(0, 255) ?? 0;
        final int green =
            (toolCall.arguments['g'] as num?)?.toInt().clamp(0, 255) ?? 0;
        final int blue =
            (toolCall.arguments['b'] as num?)?.toInt().clamp(0, 255) ?? 0;

        // Ensure led_id is int (1-12) or string "all"
        dynamic cleanLedId;
        if (ledId == 'all' || ledId == 'ALL') {
          cleanLedId = 'all';
        } else if (ledId is num) {
          cleanLedId = ledId.toInt().clamp(1, 12);
        } else if (ledId is String) {
          final parsed = int.tryParse(ledId);
          cleanLedId = parsed != null ? parsed.clamp(1, 12) : 'all';
        } else {
          cleanLedId = 'all';
        }

        return [
          {
            'command': 'SET_LED_COLOR',
            'params': {'led_id': cleanLedId, 'r': red, 'g': green, 'b': blue},
          },
        ];

      case 'display_icon':
        final iconName =
            (toolCall.arguments['icon_name'] as String?) ?? 'happy';
        return [
          {
            'command': 'DISPLAY_ICON',
            'params': {'icon_name': iconName},
          },
        ];

      case 'set_head_position':
        final pitch =
            (toolCall.arguments['pitch'] as num?)?.toInt().clamp(80, 100) ?? 90;
        final yaw =
            (toolCall.arguments['yaw'] as num?)?.toInt().clamp(80, 100) ?? 90;
        return [
          {
            'command': 'SET_HEAD_POSITION',
            'params': {'pitch': pitch, 'yaw': yaw},
          },
        ];

      case 'play_sound':
        final soundId =
            (toolCall.arguments['sound_id'] as num?)?.toInt().clamp(1, 4) ?? 1;
        return [
          {
            'command': 'PLAY_INTERNAL_SOUND',
            'params': {'sound_id': soundId},
          },
        ];

      default:
        return null;
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
            if (params.containsKey('speed')) {
              final int speed = (params['speed'] as num).toInt();
              safeParams['speed'] = speed.clamp(0, 100);
            }
          } else {
            safeParams = {};
          }
          // Provide default duration for motion commands if missing
          if (item['command'] == 'DRIVE_DIRECT' &&
              !safeParams.containsKey('duration_ms')) {
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

      // Option A: single high-level command -> map to MOVE_TIMED / TURN_TIMED
      final String command = args['command'] as String;
      int durationMs = args['duration_ms'] as int? ?? 1000;
      int speed = args['speed'] as int? ?? 100;

      // --- GUARDRAIL 2: Speed Clamp ---
      if (speed > 100) {
        speed = 100;
        debugPrint("⚠️ Speed capped at 100");
      } else if (speed < 0) {
        speed = 0;
      }

      // --- GUARDRAIL 3: Duration Limit (Safety) ---
      const int kMaxDurationMs = 10000; // 10 seconds
      if (durationMs > kMaxDurationMs) {
        durationMs = kMaxDurationMs;
        debugPrint("⚠️ Duration capped at 10s for safety");
      }

      // Map to hardware commands
      Map<String, dynamic> hardwareCommand;

      switch (command.toLowerCase()) {
        case 'move_forward':
        case 'forward':
        case 'maju':
          hardwareCommand = {
            'command': 'MOVE_TIMED',
            'params': {
              'direction': 'forward',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'move_backward':
        case 'backward':
        case 'mundur':
          hardwareCommand = {
            'command': 'MOVE_TIMED',
            'params': {
              'direction': 'backward',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'turn_left':
        case 'left':
        case 'kiri':
          hardwareCommand = {
            'command': 'TURN_TIMED',
            'params': {
              'direction': 'left',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'turn_right':
        case 'right':
        case 'kanan':
          hardwareCommand = {
            'command': 'TURN_TIMED',
            'params': {
              'direction': 'right',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'spin_left':
        case 'rotate_left':
        case 'putar_kiri':
          hardwareCommand = {
            'command': 'TURN_TIMED',
            'params': {
              'direction': 'left',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'spin_right':
        case 'rotate_right':
        case 'putar_kanan':
          hardwareCommand = {
            'command': 'TURN_TIMED',
            'params': {
              'direction': 'right',
              'speed': speed,
              'duration_ms': durationMs,
            },
          };
          break;

        case 'stop':
        case 'berhenti':
          hardwareCommand = {
            'command': 'DRIVE_DIRECT',
            'params': {'left_speed': 0, 'right_speed': 0},
          };
          break;

        default:
          return 'ERROR: Unknown command $command';
      }

      // Execute command (or queue if busy)
      return await _runOrQueueSequence(jsonEncode([hardwareCommand]));
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
      final educationalPrompt =
          """
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
