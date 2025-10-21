import * as THREE from 'three';
import { Simulator } from './simulator';

interface VirtualObstacle {
    position: THREE.Vector2;
    radius: number;
}

interface LoopFrame {
    type: 'finite' | 'infinite';
    startIndex: number;
    iterationsLeft?: number;
}

export class SimulatorSequencer {
    private simulator: Simulator;
    private isRunning: boolean = false;
    private stopRequested: boolean = false;
    private virtualObstacles: VirtualObstacle[] = [];
    public virtualPosition: THREE.Vector2 = new THREE.Vector2(0, 0);

    constructor(simulator: Simulator) {
        this.simulator = simulator;
        this.setupEnvironment();
    }

    public resetSimulationState(): void {
        console.log("--- Resetting Simulation State ---");
        this.virtualPosition.set(0, 0);
        if (this.simulator.robotModel) {
            this.simulator.robotModel.rotation.set(0, 0, 0);
        }
    }

    public async runCommandSequence(commands: any[]): Promise<void> {
        if (this.isRunning) { return; }
        this.isRunning = true;
        this.stopRequested = false;
        
        let pc = 0; // Program Counter
        const loopStack: LoopFrame[] = [];

        console.log("--- Starting Simulation Interpreter ---");
        try {
            while (pc < commands.length && !this.stopRequested) {
                const command = commands[pc];
                const commandName = command.command;

                let pcIncrement = 1;

                switch (commandName) {
                    // --- Standard Commands ---
                    case 'MOVE_TIMED':
                    case 'TURN_TIMED':
                    case 'WAIT':
                    case 'SET_HEAD_POSITION':
                    case 'SET_LED_COLOR':
                    case 'DISPLAY_ICON':
                    case 'PLAY_INTERNAL_SOUND': {
                        await this.executeActionCommand(command);
                        break;
                    }

                    // --- Loop Commands ---
                    case 'META_START_LOOP': {
                        loopStack.push({
                            type: 'finite',
                            startIndex: pc + 1,
                            iterationsLeft: command.params.times,
                        });
                        break;
                    }
                    case 'META_START_INFINITE_LOOP': {
                        loopStack.push({
                            type: 'infinite',
                            startIndex: pc + 1,
                        });
                        break;
                    }
                    case 'META_END_LOOP': {
                        if (loopStack.length > 0) {
                            const currentLoop = loopStack[loopStack.length - 1];
                            if (currentLoop.type === 'infinite') {
                                pc = currentLoop.startIndex;
                                pcIncrement = 0;
                            } else if (currentLoop.iterationsLeft! > 1) {
                                currentLoop.iterationsLeft!--;
                                pc = currentLoop.startIndex;
                                pcIncrement = 0;
                            } else {
                                loopStack.pop();
                            }
                        }
                        break;
                    }
                    case 'META_BREAK_LOOP': {
                        if (loopStack.length > 0) {
                            loopStack.pop();
                            pc = this.findMatchingEndLoop(commands, pc);
                        }
                        break;
                    }

                    // --- Conditional Commands ---
                    case 'META_IF':
                    case 'META_ELSE_IF': {
                        const conditionMet = this.evaluateCondition(command.params.condition);
                        if (!conditionMet) {
                            pc = this.findNextBranch(commands, pc);
                        }
                        break;
                    }
                    case 'META_ELSE': {
                        pc = this.findMatchingEndIf(commands, pc);
                        break;
                    }
                }
                pc += pcIncrement;
            }
        } catch (error) { console.error("Error during simulation sequence:", error);
        } finally {
            this.stopAllMovement();
            console.log("--- Simulation Interpreter Finished ---");
            this.isRunning = false;
        }
    }

    private evaluateCondition(condition: string): boolean {
        console.log(`Evaluating Condition: ${condition}`);
        const sandbox = {
            getSensorValue: (commandJson: string): number | null => {
                try {
                    const command = JSON.parse(commandJson);
                    if (command.params && command.params.sensor) {
                        switch(command.params.sensor) {
                            case 'DISTANCE':
                            case 'proximity_front':
                                return this.getDistance();
                        }
                    }
                    return null;
                } catch (e) {
                    return null;
                }
            }
        };
        try {
            const evaluator = new Function('getSensorValue', `return ${condition};`);            
            const result = evaluator(sandbox.getSensorValue);
            return result === true;

        } catch (error) {
            console.error(`Error evaluating condition "${condition}":`, error);
            return false;
        }
    }

    private findMatchingEndLoop(commands: any[], startIndex: number): number {
        let nestLevel = 0;
        for (let i = startIndex + 1; i < commands.length; i++) {
            const cmd = commands[i].command;
            if (cmd === 'META_START_LOOP' || cmd === 'META_START_INFINITE_LOOP') {
                nestLevel++;
            } else if (cmd === 'META_END_LOOP') {
                if (nestLevel === 0) return i;
                nestLevel--;
            }
        }
        return commands.length;
    }

    private findNextBranch(commands: any[], startIndex: number): number {
        let nestLevel = 0;
        for (let i = startIndex + 1; i < commands.length; i++) {
            const cmd = commands[i].command;
            if (cmd === 'META_IF') nestLevel++;
            if (cmd === 'META_END_IF') {
                if (nestLevel === 0) return i;
                nestLevel--;
            }
            if (nestLevel === 0 && (cmd === 'META_ELSE_IF' || cmd === 'META_ELSE')) {
                return i;
            }
        }
        return commands.length;
    }
    
    private findMatchingEndIf(commands: any[], startIndex: number): number {
        let nestLevel = 0;
        for (let i = startIndex + 1; i < commands.length; i++) {
            const cmd = commands[i].command;
            if (cmd === 'META_IF') nestLevel++;
            if (cmd === 'META_END_IF') {
                if (nestLevel === 0) return i;
                nestLevel--;
            }
        }
        return commands.length;
    }

    private setupEnvironment(): void {
        this.simulator.clearObstacles();
        this.virtualObstacles = [];
        this.addVirtualObstacle(new THREE.Vector2(0, 3), 0.5);
        this.addVirtualObstacle(new THREE.Vector2(0, -3), 0.5);
        this.addVirtualObstacle(new THREE.Vector2(2, 5), 0.7);
        this.addVirtualObstacle(new THREE.Vector2(-4, 4), 1.0);
    }

    private addVirtualObstacle(position: THREE.Vector2, radius: number): void {
        this.virtualObstacles.push({ position, radius });
        this.simulator.addObstacle(position, radius);
    }

    public stopSequence(): void {
        if (this.isRunning) { this.stopRequested = true; }
    }

    private stopAllMovement(): void {
        this.simulator.stopWheelAnimation('L');
        this.simulator.stopWheelAnimation('R');
        this.simulator.stopWheelAnimation('B');
    }

    private executeActionCommand(command: any): Promise<void> {
        const { command: commandName, params } = command;
        switch(commandName) {
            case 'SET_HEAD_POSITION': this.simulator.setHeadPosition(params.pitch, params.yaw); break;
            case 'SET_LED_COLOR': this.simulator.setLedColor(params.led_id, new THREE.Color(params.r / 255, params.g / 255, params.b / 255)); break;
            case 'DISPLAY_ICON': this.simulator.displayIcon(params.icon_name); break;
            case 'PLAY_INTERNAL_SOUND': this.simulator.playSound(params.sound_id); break;
        }
        if (commandName === 'MOVE_TIMED' || commandName === 'TURN_TIMED' || commandName === 'WAIT') {
            return new Promise(resolve => this.runTimedCommand(command, resolve));
        }
        return Promise.resolve();
    }

    private runTimedCommand(command: any, resolve: () => void): void {
        const { command: commandName, params } = command;
        const robot = this.simulator.robotModel!;
        const startTime = performance.now();
        let lastTime = startTime;
        const duration = params.duration_ms || 0;
        if (commandName === 'MOVE_TIMED' || commandName === 'TURN_TIMED') {
            const { direction } = params;
            const isTurn = commandName === 'TURN_TIMED';
            this.simulator.playWheelAnimation('L', isTurn ? (direction === 'left' ? 'Backward' : 'Forward') : (direction === 'forward' ? 'Forward' : 'Backward'));
            this.simulator.playWheelAnimation('R', isTurn ? (direction === 'left' ? 'Forward' : 'Backward') : (direction === 'forward' ? 'Forward' : 'Backward'));
        }
        const tick = (currentTime: number) => {
            const elapsedTime = currentTime - startTime;
            if (elapsedTime >= duration || this.stopRequested) {
                this.stopAllMovement();
                return resolve();
            }
            const deltaTime = (currentTime - lastTime) / 1000.0;
            lastTime = currentTime;
            switch (commandName) {
                case 'MOVE_TIMED': {
                        const { direction, speed } = params;
                        const moveSpeed = 0.5 * (speed / 100);
                        const forwardVector = new THREE.Vector3(0, 0, 1).applyQuaternion(robot.quaternion);
                        const distance = moveSpeed * deltaTime;
                        let moveDelta = new THREE.Vector2(forwardVector.x, forwardVector.z).multiplyScalar(distance);
                        if (direction === 'backward') { moveDelta.negate(); }
                        this.virtualPosition.add(moveDelta);
                        break;
                    }
                    case 'TURN_TIMED': {
                        const { direction, speed } = params;
                        const turnDirection = direction === 'left' ? 1 : -1;
                        const turnSpeed = 1.0 * (speed / 100);
                        const angleDelta = turnDirection * turnSpeed * deltaTime;
                        robot.rotateY(angleDelta);
                        break;
                    }
            }
            requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
    }

    private getDistance(): number {
        if (!this.simulator.robotModel) return Infinity;
        const MAX_SENSOR_RANGE = 5.0;
        const forwardVector3D = new THREE.Vector3(0, 0, 1).applyQuaternion(this.simulator.robotModel.quaternion);
        const rayDirection = new THREE.Vector2(forwardVector3D.x, forwardVector3D.z).normalize();
        const rayOrigin = this.virtualPosition;
        let closestDistance = MAX_SENSOR_RANGE;
        for (const obstacle of this.virtualObstacles) {
            const L = obstacle.position.clone().sub(rayOrigin);
            const tca = L.dot(rayDirection);
            if (tca < 0) continue;
            const d2 = L.dot(L) - tca * tca;
            const r2 = obstacle.radius * obstacle.radius;
            if (d2 > r2) continue;
            const thc = Math.sqrt(r2 - d2);
            const t0 = tca - thc;
            if (t0 < closestDistance) { closestDistance = t0; }
        }
        console.log(`Sensor Distance: ${closestDistance.toFixed(2)} meters`);
        return closestDistance;
    }
}