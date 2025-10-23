// lib/models/agentic_response.dart

/// Represents the result of an agentic AI interaction
class AgenticResponse {
  final String message;
  final List<ToolCall> toolCalls;
  final bool requiresConfirmation;
  final Map<String, dynamic>? metadata;

  AgenticResponse({
    required this.message,
    this.toolCalls = const [],
    this.requiresConfirmation = false,
    this.metadata,
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get isSuccess => toolCalls.every((call) => call.success);
}

/// Represents a single tool call made by the AI
class ToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;
  final String result;
  final bool success;
  final String? errorMessage;

  ToolCall({
    required this.toolName,
    required this.arguments,
    required this.result,
    this.success = true,
    this.errorMessage,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      toolName: json['tool'] as String,
      arguments: json['args'] as Map<String, dynamic>? ?? {},
      result: '',
      success: false,
    );
  }

  ToolCall copyWith({
    String? result,
    bool? success,
    String? errorMessage,
  }) {
    return ToolCall(
      toolName: toolName,
      arguments: arguments,
      result: result ?? this.result,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Available tool types for the agentic AI
enum ToolType {
  getRobotStatus,
  executeRobotCommand,
  explainConcept,
  stopRobot,
}

/// Tool definition for AI context
class AITool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AITool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}
