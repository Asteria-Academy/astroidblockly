import * as THREE from 'three';
import { Simulator, ROBOT_LINEAR_RADIUS, ROBOT_TURNING_RADIUS} from './simulator';

interface VirtualObstacle {
    position: THREE.Vector2;
    radius: number;
}

interface LoopFrame {
    type: 'finite' | 'infinite';
    startIndex: number;
    iterationsLeft?: number;
}

const MAX_SENSOR_RANGE = 5.0;
const SENSOR_WIDTH_OFFSET = 0.25;

export class SimulatorSequencer {
    private simulator: Simulator;
    private isRunning: boolean = false;
    private stopRequested: boolean = false;
    public virtualPosition: THREE.Vector2 = new THREE.Vector2(0, 0);
    private virtualObstacles: VirtualObstacle[] = [];
    private lastCollisionLogTime: number = 0;
    private lastCollisionNotificationTime: number = 0;
    private readonly COLLISION_LOG_THROTTLE_MS = 500; // Only log collision once per 500ms
    private readonly COLLISION_NOTIFICATION_THROTTLE_MS = 500; // Only show notification once per 500ms
    private notificationElement: HTMLDivElement | null = null;

    // --- Lifecycle & Public Control API ---
    constructor(simulator: Simulator) {
        this.simulator = simulator;
        this.setupEnvironment();
        this.createNotificationElement();
    }

    private createNotificationElement(): void {
        const simulatorContainer = document.getElementById('simulator-container');
        if (!simulatorContainer) return;

        this.notificationElement = document.createElement('div');
        this.notificationElement.id = 'collision-notification';
        this.notificationElement.style.cssText = `
            position: absolute;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background-color: rgba(255, 87, 34, 0.95);
            color: white;
            padding: 12px 24px;
            border-radius: 8px;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            font-size: 14px;
            font-weight: 500;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            z-index: 1000;
            display: none;
            align-items: center;
            gap: 8px;
        `;
        simulatorContainer.appendChild(this.notificationElement);
    }

    private showCollisionNotification(message: string): void {
        if (!this.notificationElement) return;

        // Throttle notifications to prevent spam in forever loops
        const now = performance.now();
        if (now - this.lastCollisionNotificationTime < this.COLLISION_NOTIFICATION_THROTTLE_MS) {
            return; // Skip this notification, too soon since last one
        }
        this.lastCollisionNotificationTime = now;

        this.notificationElement.innerHTML = `
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
                <line x1="12" y1="9" x2="12" y2="13"></line>
                <line x1="12" y1="17" x2="12.01" y2="17"></line>
            </svg>
            <span>${message}</span>
        `;
        this.notificationElement.style.display = 'flex';

        // Auto-hide after 3 seconds
        setTimeout(() => {
            if (this.notificationElement) {
                this.notificationElement.style.display = 'none';
            }
        }, 3000);
    }

    public async runCommandSequence(commands: any[]): Promise<void> {
        if (this.isRunning) { return; }
        this.isRunning = true;
        this.stopRequested = false;
        
        let pc = 0;
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

    public stopSequence(): void {
        if (this.isRunning) { this.stopRequested = true; }
    }

    public resetSimulationState(): void {
        console.log("--- Resetting Simulation State ---");
        this.virtualPosition.set(0, 0);
        if (this.simulator.robotModel) {
            this.simulator.robotModel.rotation.set(0, 0, 0);
        }
    }

    // --- Core Interpreter Action Handlers ---
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
        
        // Pre-check for turning clearance - but don't spam console!
        if (commandName === 'TURN_TIMED') {
            const turningClearanceMultiplier = ROBOT_TURNING_RADIUS / ROBOT_LINEAR_RADIUS;
            if (this.isCollisionAt(this.virtualPosition, turningClearanceMultiplier)) {
                console.log("Turn cancelled: Not enough clearance.");
                this.showCollisionNotification("⚠️ Cannot turn - obstacle too close!");
                this.stopAllMovement();
                // Add a small delay to prevent infinite loop spam in forever loops
                setTimeout(() => resolve(), 50);
                return;
            }
        }
        
        const startTime = performance.now();
        let lastTime = startTime;
        const duration = params.duration_ms || 0;

        // Handle WAIT command (just a delay, no movement)
        if (commandName === 'WAIT') {
            setTimeout(() => {
                if (this.stopRequested) {
                    this.stopAllMovement();
                }
                resolve();
            }, duration);
            return;
        }

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
                    const nextPosition = this.virtualPosition.clone().add(moveDelta);
                    
                    if (!this.isCollisionAt(nextPosition)) {
                        this.virtualPosition.copy(nextPosition);
                    } else {
                        this.showCollisionNotification("🛑 Movement stopped - obstacle detected!");
                        this.stopAllMovement();
                        return resolve();
                    }
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

    // --- Condition & Sensor Evaluation Helpers ---
    private evaluateCondition(condition: string): boolean {
        const trimmed = condition.trim().toLowerCase();
        if (trimmed === 'true') return true;
        if (trimmed === 'false') return false;

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
            },
            mathRandomInt: (min: number, max: number): number => {
                return Math.floor(Math.random() * (max - min + 1)) + min;
            }
        };
        try {
            const evaluator = new Function('getSensorValue', 'mathRandomInt', `return ${condition};`);            
            const result = evaluator(sandbox.getSensorValue, sandbox.mathRandomInt);
            return result === true;

        } catch (error) {
            console.error(`Error evaluating condition "${condition}":`, error);
            return false;
        }
    }

    private isCollisionAt(position: THREE.Vector2, clearanceMultiplier: number = 1.0): boolean {
        const effectiveRobotRadius = ROBOT_LINEAR_RADIUS * clearanceMultiplier;

        for (const obstacle of this.virtualObstacles) {
            const distanceToObstacle = position.distanceTo(obstacle.position);
            const minimumSafeDistance = effectiveRobotRadius + obstacle.radius;
            if (distanceToObstacle < minimumSafeDistance) {
                const now = performance.now();
                if (now - this.lastCollisionLogTime > this.COLLISION_LOG_THROTTLE_MS) {
                    console.log(`Collision detected! Effective radius ${effectiveRobotRadius.toFixed(2)}m`);
                    this.lastCollisionLogTime = now;
                }
                return true;
            }
        }
        return false;
    }

    private getDistance(): number {
        if (!this.simulator.robotModel) return MAX_SENSOR_RANGE;
        const forwardVector = new THREE.Vector2(0, 1).rotateAround(new THREE.Vector2(), -this.simulator.robotModel.rotation.y);
        const rightVector = new THREE.Vector2(1, 0).rotateAround(new THREE.Vector2(), -this.simulator.robotModel.rotation.y);

        const centerRayOrigin = this.virtualPosition.clone();
        const leftRayOrigin = centerRayOrigin.clone().add(rightVector.clone().multiplyScalar(-SENSOR_WIDTH_OFFSET));
        const rightRayOrigin = centerRayOrigin.clone().add(rightVector.clone().multiplyScalar(SENSOR_WIDTH_OFFSET));

        const rayOrigins = [centerRayOrigin, leftRayOrigin, rightRayOrigin];
        let closestDistance = MAX_SENSOR_RANGE;

        for (const rayOrigin of rayOrigins) {
            for (const obstacle of this.virtualObstacles) {
                const L = obstacle.position.clone().sub(rayOrigin);
                const tca = L.dot(forwardVector);
                if (tca < 0) continue;
                
                const d2 = L.dot(L) - tca * tca;
                const r2 = obstacle.radius * obstacle.radius;
                if (d2 > r2) continue;
                
                const thc = Math.sqrt(r2 - d2);
                
                const intersectionDistance = tca - thc;

                if (intersectionDistance < closestDistance) {
                    closestDistance = intersectionDistance;
                }
            }
        }
        
        const distanceFromBumper = closestDistance - ROBOT_LINEAR_RADIUS;
        
        return Math.max(0, distanceFromBumper);
    }

    // --- Interpreter Program Counter (PC) Jump Helpers ---
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

    // --- Environment & General Helpers ---
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

    private stopAllMovement(): void {
        this.simulator.stopWheelAnimation('L');
        this.simulator.stopWheelAnimation('R');
        this.simulator.stopWheelAnimation('B');
    }
}