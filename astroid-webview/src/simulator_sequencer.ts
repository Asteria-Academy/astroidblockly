import * as THREE from 'three';
import { Simulator } from './simulator';

function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export class SimulatorSequencer {
    private simulator: Simulator;
    private isRunning: boolean = false;
    private stopRequested: boolean = false;
    private virtualPosition: THREE.Vector2 = new THREE.Vector2(0, 0);

    constructor(simulator: Simulator) {
        this.simulator = simulator;
    }

    public resetWorldState(): void {
        this.virtualPosition.set(0, 0);
        if (this.simulator.robotModel) {
            this.simulator.robotModel.rotation.set(0, 0, 0);
        }
        this.updateGroundTexture();
    }

    public async runCommandSequence(commands: any[]): Promise<void> {
        if (this.isRunning) {
            console.warn("Sequencer is already running. Ignoring new request.");
            return;
        }

        this.isRunning = true;
        this.stopRequested = false;
        if (this.simulator.robotModel) {
            this.simulator.robotModel.position.set(0, 0, 0);
            this.simulator.robotModel.position.y -= new THREE.Box3().setFromObject(this.simulator.robotModel).min.y;
        }

        console.log("--- Starting Simulation Sequence ---");

        try {
            await this.executeBlock(commands, 0);
        } catch (error) {
            console.error("Error during simulation sequence:", error);
        } finally {
            this.stopAllMovement();
            console.log("--- Simulation Sequence Finished ---");
            this.isRunning = false;
        }
    }

    public stopSequence(): void {
        if (this.isRunning) {
            this.stopRequested = true;
        }
    }

    private stopAllMovement(): void {
        this.simulator.stopWheelAnimation('L');
        this.simulator.stopWheelAnimation('R');
        this.simulator.stopWheelAnimation('B');
    }

    private updateGroundTexture(): void {
        if (this.simulator.groundMaterial) {
            const textureScaleFactor = 8 / 20;
            const textureOffset = this.virtualPosition.clone().multiplyScalar(textureScaleFactor);
            this.simulator.groundMaterial.map?.offset.set(textureOffset.x, -textureOffset.y);
            this.simulator.groundMaterial.normalMap?.offset.set(textureOffset.x, -textureOffset.y);
            this.simulator.groundMaterial.roughnessMap?.offset.set(textureOffset.x, -textureOffset.y);
        }
    }

    private async executeBlock(commands: any[], index: number): Promise<number> {
        let i = index;
        while (i < commands.length) {
            if (this.stopRequested) {
                console.log("Stop requested, halting sequence.");
                return commands.length;
            }

            const command = commands[i];
            const commandName = command.command;
            const params = command.params;

            switch (commandName) {
                case 'MOVE_TIMED': {
                    const { direction, speed, duration_ms } = params;
                    console.log(`Executing MOVE_TIMED: ${direction}, ${duration_ms}ms`);
                    
                    const moveDirection = direction === 'forward' ? 1 : -1;
                    const moveSpeed = 0.5 * speed / 100;

                    this.simulator.playWheelAnimation('L', direction === 'forward' ? 'Forward' : 'Backward');
                    this.simulator.playWheelAnimation('R', direction === 'forward' ? 'Forward' : 'Backward');

                    const startTime = Date.now();
                    while (Date.now() - startTime < duration_ms) {
                        if (this.stopRequested) break;
                        
                        if (this.simulator.robotModel) {
                            const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(this.simulator.robotModel.quaternion);
                            
                            const distance = moveDirection * moveSpeed * (16 / 1000);
                            const moveDelta = new THREE.Vector2(forward.x, forward.z).multiplyScalar(distance);
                            
                            this.virtualPosition.add(moveDelta);                            
                            this.updateGroundTexture();
                        }
                        await sleep(16);
                    }
                    this.stopAllMovement();
                    break;
                }
                case 'TURN_TIMED': {
                    const { direction, speed, duration_ms } = params;
                    console.log(`Executing TURN_TIMED: ${direction}, ${duration_ms}ms`);

                    const turnDirection = direction === 'left' ? 1 : -1;
                    const turnSpeed = 1.0 * speed / 100;

                    this.simulator.playWheelAnimation('L', direction === 'left' ? 'Backward' : 'Forward');
                    this.simulator.playWheelAnimation('R', direction === 'left' ? 'Forward' : 'Backward');

                    const startTime = Date.now();
                    let lastTime = startTime;
                    while (Date.now() - startTime < duration_ms) {
                        if (this.stopRequested) break;

                        const currentTime = Date.now();
                        const deltaTime = (currentTime - lastTime) / 1000.0;
                        lastTime = currentTime;

                        if (this.simulator.robotModel) {
                            const angleDelta = turnDirection * turnSpeed * deltaTime;
                            this.simulator.robotModel.rotateY(angleDelta);
                            this.virtualPosition.rotateAround(new THREE.Vector2(0,0), -angleDelta);
                        }
                        await sleep(16);
                    }
                    this.updateGroundTexture();
                    this.stopAllMovement();
                    break;
                }
                
                case 'WAIT': {
                    const { duration_ms } = params;
                    console.log(`Executing WAIT: ${duration_ms}ms`);
                    await sleep(duration_ms);
                    break;
                }

                // We'll add META_START_LOOP here in the next step
            }
            i++;
        }
        return i;
    }
}