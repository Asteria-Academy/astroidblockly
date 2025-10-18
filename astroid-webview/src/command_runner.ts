export function runCommandsOnRobot(commandJsonString: string): void {
  console.log('--- Sending Code to Robot ---');
  console.log(commandJsonString);

  if (window.astroidAppChannel) {
    window.astroidAppChannel(commandJsonString);
  } else {
    console.log("Running in a standard browser. 'astroidAppChannel' not found.");
  }
}