// src/robotProfiles.ts

export interface RobotProfile {
  name: string;
  commands: {
    // Drive System
    moveForward: 'MOVE_FORWARD';
    moveBackward: 'MOVE_BACKWARD';
    turnLeft: 'TURN_LEFT';
    turnRight: 'TURN_RIGHT';
    spinLeft: 'SPIN_LEFT';
    spinRight: 'SPIN_RIGHT';
    stop: 'STOP';

    // Neck Servos
    setNeckPitch: 'SET_NECK_PITCH'; // Param: angle
    setNeckYaw: 'SET_NECK_YAW';     // Param: angle

    // Head
    setLed: 'SET_LED';               // Param: r, g, b
    showExpression: 'SHOW_EXPRESSION'; // Param: emotion ('HAPPY', 'SAD', etc.)

    // Gripper (High-level commands)
    openGripper: 'OPEN_GRIPPER';
    closeGripper: 'CLOSE_GRIPPER';

    // Audio
    playSound: 'PLAY_SOUND';
    danceMode: 'DANCE_MODE';

    // Sensors
    getSensorData: 'GET_SENSOR_DATA';
  };
}

export const astroidV2: RobotProfile = {
  name: 'Astroid V2 (ESP32)',
  commands: {
    // Drive
    moveForward: 'MOVE_FORWARD',
    moveBackward: 'MOVE_BACKWARD',
    turnLeft: 'TURN_LEFT',
    turnRight: 'TURN_RIGHT',
    spinLeft: 'SPIN_LEFT',
    spinRight: 'SPIN_RIGHT',
    stop: 'STOP',
    // Neck
    setNeckPitch: 'SET_NECK_PITCH',
    setNeckYaw: 'SET_NECK_YAW',
    // Head
    setLed: 'SET_LED',
    showExpression: 'SHOW_EXPRESSION',
    // Gripper
    openGripper: 'OPEN_GRIPPER',
    closeGripper: 'CLOSE_GRIPPER',
    // Audio
    playSound: 'PLAY_SOUND',
    danceMode: 'DANCE_MODE',
    // Sensors
    getSensorData: 'GET_SENSOR_DATA',
  },
};