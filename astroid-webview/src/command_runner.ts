// src/command_runner.ts

interface CommandObject {
  command: string;
  params: { [key: string]: any };
}

export function runCommands(generatedCode: string): void {
  console.log('--- Raw Generated Code ---');
  console.log(generatedCode);

  const commandStrings = generatedCode.split(';').filter(Boolean);

  let commandArray: CommandObject[] = [];

  try {
    commandArray = commandStrings.map(str => JSON.parse(str));
  } catch (e) {
    console.error("Failed to parse generated JSON!", e);
    console.error("Problematic string:", generatedCode);
    return;
  }

  console.log('--- Parsed Command Array (IR) ---');
  console.log(commandArray);  

  if (window.astroidAppChannel) {
    window.astroidAppChannel(JSON.stringify(commandArray));
  } else {
    console.log("Running in a standard browser. 'astroidAppChannel' not found.");
  }
}