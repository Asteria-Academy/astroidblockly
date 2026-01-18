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

  // Context trimming to avoid oversized prompts
  static const int _maxContextChars = 8000;
  static const int _maxHistoryMessages = 8;

  // Motion tuning
  static const double _turnDurationScale = 0.55;
  static const double _turnSpeedScale = 0.6;
  static const double _uTurnDurationScale = 0.7;
  static const double _uTurnSpeedScale = 0.45;
  static const int _minTurnDurationMs = 350;
  static const int _maxTurnDurationMs = 1200;
  static const int _maxUTurnDurationMs = 1400;
  static const int _minTurnSpeed = 35;
  static const int _interCommandGapMs = 500;
  static const int _minMoveSpeed = 40;
  static const int _minMoveDurationMs = 400;


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
              'u_turn_left',
              'u_turn_right',
              'balik_kiri',
              'balik_kanan',
              'putar_balik_kiri',
              'putar_balik_kanan',
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
      // Build context with agentic system prompt (trim history if needed)
      final contextResult = _buildContextWithPrompt(conversationHistory);
      if (contextResult.shouldReset) {
        return AgenticResponse(
          message:
              'Chat terlalu panjang untuk diproses. Silakan kembali ke page code atau chat akan direset agar bisa lanjut.',
          metadata: const {'resetChat': true},
        );
      }
      final List<ChatMessage> contextWithPrompt = contextResult.context;

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
      List<ToolCall> toolCallResults = _parseToolCalls(aiResponse);

      if (toolCallResults.isEmpty) {
        final fallbackCalls = _buildFallbackToolCalls(userMessage);
        if (fallbackCalls.isNotEmpty) {
          toolCallResults = fallbackCalls;
        }
      }

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
          final List<Map<String, dynamic>> sequencedBatch =
              _injectInterCommandWait(hardwareCommandBatch, _interCommandGapMs);

          final batchToolCall = ToolCall(
            toolName: 'execute_robot_command',
            arguments: {'commands': sequencedBatch},
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
          metadata: {
            'messageSegments': responseSegments,
            'historyTrimmed': contextResult.trimmed,
          },
        );
      } else {
        // Normal text response
        return AgenticResponse(
          message: aiResponse,
          metadata: {'historyTrimmed': contextResult.trimmed},
        );
      }
    } catch (e) {
      debugPrint('AgenticAIService error: $e');
      return AgenticResponse(
        message: "Sorry, I encountered an error. Please try again.",
      );
    }
  }

  List<ToolCall> _buildFallbackToolCalls(String userMessage) {
    final List<ToolCall> calls = [];
    final segments = _splitCommandSegments(userMessage);

    for (final segment in segments) {
      calls.addAll(_buildFallbackCallsForSegment(segment));
    }

    return calls;
  }

  List<String> _splitCommandSegments(String message) {
    final normalized = message.toLowerCase();
    return normalized
        .split(RegExp(r'\b(lalu|kemudian|terus|dan)\b'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  List<ToolCall> _buildFallbackCallsForSegment(String segment) {
    final List<ToolCall> calls = [];
    final int durationMs = _extractDurationMs(segment) ?? 1000;
    final int speed = _extractSpeed(segment) ?? 80;

    final bool wantsForward = _containsAny(segment, ['maju', 'forward']);
    final bool wantsBackward = _containsAny(segment, ['mundur', 'backward']);
    final bool wantsStop = _containsAny(segment, ['stop', 'berhenti']);

    final bool wantsUTurnLeft =
        _containsAny(segment, ['putar balik kiri', 'balik kiri', 'u-turn left']);
    final bool wantsUTurnRight =
        _containsAny(segment, ['putar balik kanan', 'balik kanan', 'u-turn right']);
    final bool wantsSpinLeft = _containsAny(segment, ['spin kiri', 'spin left', 'putar kiri']);
    final bool wantsSpinRight = _containsAny(segment, ['spin kanan', 'spin right', 'putar kanan']);
    final int idxLeft = segment.indexOf('kiri');
    final int idxRight = segment.indexOf('kanan');
    final bool mentionsBelok = _containsAny(segment, ['belok', 'turn']);

    if (wantsForward) {
      calls.add(_buildMoveCall('move_forward', durationMs, speed));
    }
    if (wantsBackward) {
      calls.add(_buildMoveCall('move_backward', durationMs, speed));
    }

    if (wantsUTurnLeft) {
      calls.add(_buildMoveCall('u_turn_left', durationMs, speed));
    } else if (wantsUTurnRight) {
      calls.add(_buildMoveCall('u_turn_right', durationMs, speed));
    }

    if (wantsSpinLeft) {
      calls.add(_buildMoveCall('spin_left', durationMs, speed));
    }
    if (wantsSpinRight) {
      calls.add(_buildMoveCall('spin_right', durationMs, speed));
    }

    if (!wantsUTurnLeft && !wantsUTurnRight && (idxLeft != -1 || idxRight != -1)) {
      if (idxLeft != -1 && idxRight != -1) {
        if (idxLeft < idxRight) {
          if (mentionsBelok) {
            calls.add(_buildMoveCall('turn_left', durationMs, speed));
            calls.add(_buildMoveCall('turn_right', durationMs, speed));
          }
        } else {
          if (mentionsBelok) {
            calls.add(_buildMoveCall('turn_right', durationMs, speed));
            calls.add(_buildMoveCall('turn_left', durationMs, speed));
          }
        }
      } else if (idxLeft != -1) {
        if (mentionsBelok) {
          calls.add(_buildMoveCall('turn_left', durationMs, speed));
        }
      } else if (idxRight != -1) {
        if (mentionsBelok) {
          calls.add(_buildMoveCall('turn_right', durationMs, speed));
        }
      }
    }

    if (wantsStop) {
      calls.add(ToolCall(
        toolName: 'execute_robot_command',
        arguments: {'command': 'stop'},
        result: '',
      ));
    }

    if (_containsAny(segment, ['ekspresi', 'expression', 'senyum', 'sedih', 'marah', 'bingung'])) {
      final icon = _extractIconName(segment);
      calls.add(ToolCall(
        toolName: 'display_icon',
        arguments: {'icon_name': icon},
        result: '',
      ));
    }

    if (_containsAny(segment, ['warna', 'led', 'lampu'])) {
      final color = _extractLedColor(segment);
      if (color != null) {
        calls.add(ToolCall(
          toolName: 'set_led_color',
          arguments: {
            'led_id': 'all',
            'r': color['r'],
            'g': color['g'],
            'b': color['b'],
          },
          result: '',
        ));
      }
    }

    return calls;
  }

  ToolCall _buildMoveCall(String command, int durationMs, int speed) {
    return ToolCall(
      toolName: 'execute_robot_command',
      arguments: {
        'command': command,
        'duration_ms': durationMs,
        'speed': speed,
      },
      result: '',
    );
  }

  List<Map<String, dynamic>> _injectInterCommandWait(
    List<Map<String, dynamic>> commands,
    int gapMs,
  ) {
    if (commands.length < 2) return commands;

    final List<Map<String, dynamic>> sequenced = [];
    for (int i = 0; i < commands.length; i++) {
      sequenced.add(commands[i]);
      if (i < commands.length - 1) {
        sequenced.add({
          'command': 'WAIT',
          'params': {'duration_ms': gapMs},
        });
      }
    }
    return sequenced;
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  int? _extractDurationMs(String text) {
    final secMatch = RegExp(r'(\d+)\s*(detik|second|seconds|s)').firstMatch(text);
    if (secMatch != null) {
      final secs = int.tryParse(secMatch.group(1) ?? '');
      if (secs != null) return secs * 1000;
    }
    final msMatch = RegExp(r'(\d+)\s*ms').firstMatch(text);
    if (msMatch != null) {
      return int.tryParse(msMatch.group(1) ?? '');
    }
    return null;
  }

  int? _extractSpeed(String text) {
    if (text.contains('pelan') || text.contains('lambat') || text.contains('slow')) {
      return 50;
    }
    if (text.contains('cepat') || text.contains('fast')) {
      return 90;
    }
    final speedMatch = RegExp(r'(\d+)\s*%').firstMatch(text);
    if (speedMatch != null) {
      final val = int.tryParse(speedMatch.group(1) ?? '');
      if (val != null) return val.clamp(0, 100);
    }
    return null;
  }

  String _extractIconName(String text) {
    if (text.contains('sedih') || text.contains('sad')) return 'sad';
    if (text.contains('marah') || text.contains('angry') || text.contains('mad')) {
      return 'mad';
    }
    if (text.contains('bingung') || text.contains('confused')) return 'confused';
    return 'happy';
  }

  Map<String, int>? _extractLedColor(String text) {
    if (text.contains('merah') || text.contains('red')) return {'r': 255, 'g': 0, 'b': 0};
    if (text.contains('hijau') || text.contains('green')) return {'r': 0, 'g': 255, 'b': 0};
    if (text.contains('biru') || text.contains('blue')) return {'r': 0, 'g': 128, 'b': 255};
    if (text.contains('kuning') || text.contains('yellow')) return {'r': 255, 'g': 255, 'b': 0};
    if (text.contains('ungu') || text.contains('purple')) return {'r': 128, 'g': 0, 'b': 255};
    return null;
  }

  _ContextBuildResult _buildContextWithPrompt(
    List<ChatMessage> conversationHistory,
  ) {
    final systemMessage = ChatMessage(
      text: AppPrompts.agenticSystemPrompt,
      role: ChatRole.system,
    );

    final List<ChatMessage> userHistory = conversationHistory
        .where((msg) => msg.role != ChatRole.system)
        .toList();

    final int startIndex = userHistory.length > _maxHistoryMessages
        ? userHistory.length - _maxHistoryMessages
        : 0;
    final List<ChatMessage> windowedHistory =
        userHistory.sublist(startIndex);

    int totalChars = systemMessage.text.length;
    final List<ChatMessage> trimmedHistory = [];
    bool trimmed = userHistory.length != windowedHistory.length;

    for (int i = windowedHistory.length - 1; i >= 0; i--) {
      final msg = windowedHistory[i];
      final int msgLen = msg.text.length;
      if (totalChars + msgLen > _maxContextChars) {
        trimmed = true;
        continue;
      }
      trimmedHistory.add(msg);
      totalChars += msgLen;
    }

    if (trimmedHistory.isEmpty && userHistory.isNotEmpty) {
      return const _ContextBuildResult(
        context: [],
        trimmed: true,
        shouldReset: true,
      );
    }

    return _ContextBuildResult(
      context: [systemMessage, ...trimmedHistory.reversed],
      trimmed: trimmed,
      shouldReset: false,
    );
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

    for (final chunk in _extractJsonChunks(cleaned)) {
      try {
        final json = jsonDecode(chunk);
        if (json is Map<String, dynamic> && json.containsKey('tool')) {
          calls.add(ToolCall.fromJson(json));
        } else if (json is List) {
          for (final item in json) {
            if (item is Map<String, dynamic> && item.containsKey('tool')) {
              calls.add(ToolCall.fromJson(item));
            }
          }
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


  List<String> _extractJsonChunks(String input) {
    final List<String> chunks = [];
    int depth = 0;
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
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }

      if (char == '{' || char == '[') {
        if (depth == 0) startIndex = i;
        depth++;
      } else if (char == '}' || char == ']') {
        depth = depth > 0 ? depth - 1 : 0;
        if (depth == 0 && startIndex != -1) {
          chunks.add(input.substring(startIndex, i + 1));
          startIndex = -1;
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
        List<Map<String, dynamic>>? commandList;

        switch (command.toLowerCase()) {
          case 'move_forward':
          case 'forward':
          case 'maju':
            final normalizedForward = _normalizeMoveParams(speed, durationMs);
            singleCmd = {
              'command': 'MOVE_TIMED',
              'params': {
                'direction': 'forward',
                'speed': normalizedForward.speed,
                'duration_ms': normalizedForward.durationMs,
              },
            };
            break;

          case 'move_backward':
          case 'backward':
          case 'mundur':
            final normalizedBackward = _normalizeMoveParams(speed, durationMs);
            singleCmd = {
              'command': 'MOVE_TIMED',
              'params': {
                'direction': 'backward',
                'speed': normalizedBackward.speed,
                'duration_ms': normalizedBackward.durationMs,
              },
            };
            break;

          case 'turn_left':
          case 'left':
          case 'belok_kiri':
          case 'kiri':
            singleCmd = _buildTurnDirectCommand(
              direction: 'left',
              speed: speed,
              durationMs: durationMs,
            );
            break;

          case 'turn_right':
          case 'right':
          case 'belok_kanan':
          case 'kanan':
            singleCmd = _buildTurnDirectCommand(
              direction: 'right',
              speed: speed,
              durationMs: durationMs,
            );
            break;

          case 'spin_left':
            singleCmd = _buildTurnDirectCommand(
              direction: 'left',
              speed: speed,
              durationMs: durationMs,
            );
            break;
          case 'spin_right':
            singleCmd = _buildTurnDirectCommand(
              direction: 'right',
              speed: speed,
              durationMs: durationMs,
            );
            break;

          case 'u_turn_left':
          case 'balik_kiri':
          case 'putar_balik_kiri':
            commandList = _buildUTurnDirectCommands(
              direction: 'left',
              speed: speed,
              durationMs: durationMs,
            );
            break;

          case 'u_turn_right':
          case 'balik_kanan':
          case 'putar_balik_kanan':
            commandList = _buildUTurnDirectCommands(
              direction: 'right',
              speed: speed,
              durationMs: durationMs,
            );
            break;

          case 'stop':
            singleCmd = _buildStopCommand();
            break;
        }

        if (commandList != null) return commandList;
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
          String commandName = (item['command'] as String).toUpperCase();
          if (commandName == 'META_START_INFINITE_LOOP') {
            hasInfiniteLoop = true;
          }

          final validationError = _validateSequencerCommand(item);
          if (validationError != null) {
            return validationError;
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

          if (commandName == 'DISPLAY_ICON') {
            final iconName =
                (safeParams['icon_name'] as String?) ?? 'happy';
            safeParams['icon_name'] = iconName;
            item['params'] = safeParams;
            sequencerCommands.add(item);
            continue;
          }

          if (commandName == 'MOVE_TIMED') {
            final int rawSpeed =
                (safeParams['speed'] as num?)?.toInt() ?? 0;
            final int rawDuration =
                (safeParams['duration_ms'] as num?)?.toInt() ?? 1000;
            final normalized = _normalizeMoveParams(rawSpeed, rawDuration);
            safeParams['speed'] = normalized.speed;
            safeParams['duration_ms'] = normalized.durationMs;
          }

          // Reduce excessive turning
          if (commandName == 'TURN_TIMED') {
            final int rawDuration =
                (safeParams['duration_ms'] as num?)?.toInt() ?? 1000;
            final int rawSpeed =
                (safeParams['speed'] as num?)?.toInt() ?? 80;
            final bool isUTurn = safeParams['turn_type'] == 'uturn';
            safeParams['duration_ms'] = _scaleDuration(
              rawDuration,
              isUTurn ? _uTurnDurationScale : _turnDurationScale,
              min: _minTurnDurationMs,
              max: isUTurn ? _maxUTurnDurationMs : _maxTurnDurationMs,
            );
            safeParams['speed'] = _scaleSpeed(
              rawSpeed,
              isUTurn ? _uTurnSpeedScale : _turnSpeedScale,
              min: _minTurnSpeed,
              max: 100,
            );
          }
          // Provide default duration for motion commands if missing
          if ((item['command'] == 'MOVE_TIMED' ||
                  item['command'] == 'TURN_TIMED' ||
                  item['command'] == 'WAIT') &&
              !safeParams.containsKey('duration_ms')) {
            safeParams['duration_ms'] = 1000;
          }
          item['params'] = safeParams;
          sequencerCommands.add(item);
        }

        final sequencedWithGap =
          _injectInterCommandWait(sequencerCommands, _interCommandGapMs);
        final sequenceJson = jsonEncode(sequencedWithGap);
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
          final normalizedForward = _normalizeMoveParams(speed, durationMs);
          hardwareCommand = {
            'command': 'MOVE_TIMED',
            'params': {
              'direction': 'forward',
              'speed': normalizedForward.speed,
              'duration_ms': normalizedForward.durationMs,
            },
          };
          break;

        case 'move_backward':
        case 'backward':
        case 'mundur':
          final normalizedBackward = _normalizeMoveParams(speed, durationMs);
          hardwareCommand = {
            'command': 'MOVE_TIMED',
            'params': {
              'direction': 'backward',
              'speed': normalizedBackward.speed,
              'duration_ms': normalizedBackward.durationMs,
            },
          };
          break;

        case 'turn_left':
        case 'left':
        case 'kiri':
          hardwareCommand = _buildTurnDirectCommand(
            direction: 'left',
            speed: speed,
            durationMs: durationMs,
          );
          break;

        case 'turn_right':
        case 'right':
        case 'kanan':
          hardwareCommand = _buildTurnDirectCommand(
            direction: 'right',
            speed: speed,
            durationMs: durationMs,
          );
          break;

        case 'spin_left':
        case 'rotate_left':
        case 'putar_kiri':
          hardwareCommand = _buildTurnDirectCommand(
            direction: 'left',
            speed: speed,
            durationMs: durationMs,
          );
          break;

        case 'spin_right':
        case 'rotate_right':
        case 'putar_kanan':
          hardwareCommand = _buildTurnDirectCommand(
            direction: 'right',
            speed: speed,
            durationMs: durationMs,
          );
          break;

        case 'u_turn_left':
        case 'balik_kiri':
        case 'putar_balik_kiri':
          return await _runOrQueueSequence(
            jsonEncode(
              _buildUTurnDirectCommands(
                direction: 'left',
                speed: speed,
                durationMs: durationMs,
              ),
            ),
          );

        case 'u_turn_right':
        case 'balik_kanan':
        case 'putar_balik_kanan':
          return await _runOrQueueSequence(
            jsonEncode(
              _buildUTurnDirectCommands(
                direction: 'right',
                speed: speed,
                durationMs: durationMs,
              ),
            ),
          );

        case 'stop':
        case 'berhenti':
          hardwareCommand = _buildStopCommand();
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

  int _scaleDuration(
    int durationMs,
    double factor, {
    required int min,
    required int max,
  }) {
    final int scaled = (durationMs * factor).round();
    return scaled.clamp(min, max);
  }

  int _scaleSpeed(
    int speed,
    double factor, {
    required int min,
    required int max,
  }) {
    final int scaled = (speed * factor).round();
    return scaled.clamp(min, max);
  }

  _NormalizedMove _normalizeMoveParams(int speed, int durationMs) {
    if (speed <= 0) {
      return const _NormalizedMove(speed: 0, durationMs: _minMoveDurationMs);
    }
    final int normalizedSpeed = speed.clamp(_minMoveSpeed, 100);
    final int normalizedDuration = durationMs.clamp(_minMoveDurationMs, 10000);
    return _NormalizedMove(
      speed: normalizedSpeed,
      durationMs: normalizedDuration,
    );
  }

  Map<String, dynamic> _buildTurnDirectCommand({
    required String direction,
    required int speed,
    required int durationMs,
  }) {
    final int scaledSpeed = _scaleSpeed(
      speed,
      _turnSpeedScale,
      min: _minTurnSpeed,
      max: 100,
    );
    final int scaledDuration = _scaleDuration(
      durationMs,
      _turnDurationScale,
      min: _minTurnDurationMs,
      max: _maxTurnDurationMs,
    );

    // NOTE: Direction corrected (left/right were inverted on hardware).
    final int leftSpeed = direction == 'left' ? scaledSpeed : -scaledSpeed;
    final int rightSpeed = direction == 'left' ? -scaledSpeed : scaledSpeed;

    return {
      'command': 'DRIVE_DIRECT',
      'params': {
        'left_speed': leftSpeed,
        'right_speed': rightSpeed,
        'duration_ms': scaledDuration,
      },
    };
  }

  List<Map<String, dynamic>> _buildUTurnDirectCommands({
    required String direction,
    required int speed,
    required int durationMs,
  }) {
    final int scaledSpeed = _scaleSpeed(
      speed,
      _uTurnSpeedScale,
      min: _minTurnSpeed,
      max: 100,
    );
    final int scaledDuration = _scaleDuration(
      durationMs,
      _uTurnDurationScale,
      min: _minTurnDurationMs,
      max: _maxUTurnDurationMs,
    );

    // NOTE: Direction corrected (left/right were inverted on hardware).
    final int leftSpeed = direction == 'left' ? scaledSpeed : -scaledSpeed;
    final int rightSpeed = direction == 'left' ? -scaledSpeed : scaledSpeed;

    return [
      {
        'command': 'DRIVE_DIRECT',
        'params': {
          'left_speed': leftSpeed,
          'right_speed': rightSpeed,
          'duration_ms': scaledDuration,
        },
      },
    ];
  }

  Map<String, dynamic> _buildStopCommand() {
    return {
      'command': 'MOVE_TIMED',
      'params': {
        'direction': 'forward',
        'speed': 0,
        'duration_ms': 200,
      },
    };
  }


  String? _validateSequencerCommand(Map<String, dynamic> item) {
    final commandName = (item['command'] as String).toUpperCase();
    const allowedCommands = {
      'DRIVE_DIRECT',
      'MOVE_TIMED',
      'TURN_TIMED',
      'WAIT',
      'SET_HEAD_POSITION',
      'SET_LED_COLOR',
      'DISPLAY_ICON',
      'PLAY_INTERNAL_SOUND',
      'SET_GRIPPER',
      'META_START_LOOP',
      'META_START_INFINITE_LOOP',
      'META_END_LOOP',
      'META_BREAK_LOOP',
      'META_IF',
      'META_ELSE_IF',
      'META_ELSE',
      'META_END_IF',
    };

    if (!allowedCommands.contains(commandName)) {
      return 'ERROR: Unsupported command "$commandName".';
    }

    if (commandName.startsWith('META_')) {
      return null;
    }

    final params = item['params'];
    if (params is! Map<String, dynamic>) {
      return 'ERROR: "$commandName" requires a params object.';
    }

    switch (commandName) {
      case 'DRIVE_DIRECT':
        if (!params.containsKey('left_speed') ||
            !params.containsKey('right_speed') ||
            !params.containsKey('duration_ms')) {
          return 'ERROR: DRIVE_DIRECT requires left_speed, right_speed, and duration_ms.';
        }
        break;
      case 'MOVE_TIMED':
        if (!params.containsKey('direction') ||
            !params.containsKey('duration_ms')) {
          return 'ERROR: MOVE_TIMED requires direction and duration_ms.';
        }
        break;
      case 'TURN_TIMED':
        if (!params.containsKey('direction') ||
            !params.containsKey('duration_ms')) {
          return 'ERROR: TURN_TIMED requires direction and duration_ms.';
        }
        break;
      case 'WAIT':
        if (!params.containsKey('duration_ms')) {
          return 'ERROR: WAIT requires duration_ms.';
        }
        break;
      default:
        break;
    }

    return null;
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
    return '';
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
      return '';
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

class _ContextBuildResult {
  final List<ChatMessage> context;
  final bool trimmed;
  final bool shouldReset;

  const _ContextBuildResult({
    required this.context,
    required this.trimmed,
    required this.shouldReset,
  });
}

class _NormalizedMove {
  final int speed;
  final int durationMs;

  const _NormalizedMove({required this.speed, required this.durationMs});
}
