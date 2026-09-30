# Architecture

This document explains how the Automatic Screwdriver Line is built, why it is built that way, and what is deliberately left unfinished. It is written for an engineer who wants to understand the design, not only run it.

The PLC code referenced here can be read in [`src/`](../src), and the robot program in [`cobot/ScrewLineProgram.script`](../cobot/ScrewLineProgram.script).

## 1. Goal and scope

The project is a learning exercise with a production mindset: a small screwdriving cell, fully simulated, but designed as if it had to be maintained, extended and handed over.

Three questions drove the design:

1. Can the orchestration logic stay unchanged when a device is replaced by a completely different technology (a linear axis by a robot)?
2. Can a PLC and a robot exchange commands over a plain fieldbus without timing assumptions that break under load?
3. Can every failure be detected, reported and recovered from, without hardware?

## 2. Software architecture

```
                     PLC_PRG
          (instantiation, injection, I/O mapping)
                        │
                        ▼
                  FB_JobManager ──────────────► FB_ReportJob ──► I_ReportSink
               (job state machine)                                   │
       ┌──────────┬─────┴──────┬────────────┐                  FB_LogSink
       ▼          ▼            ▼            ▼                (FB_MqttSink, planned)
 FB_UserInterface FB_JobSelector  I_Mover   FB_zAxis  FB_Spindle
   (start/stop)   (recipe)         │
                            ┌──────┴──────┐
                         FB_Cobot   FB_ConveyorElectrical
```

| Layer | Responsibility |
|---|---|
| `PLC_PRG` | Creates every instance, injects dependencies once (`InitPous`), maps function block I/O to the I/O images. Contains no logic. |
| `FB_JobManager` | Sequences a job. Knows *what* must happen, never *how* a device does it. |
| `FB_JobSelector` | Walks through the screw recipe. |
| `FB_UserInterface` | Turns the start and stop requests into single-cycle commands (rising edges). There is no HMI: the requests are written from the CODESYS watch window. |
| Devices | `FB_Cobot`, `FB_ConveyorElectrical`, `FB_zAxis`, `FB_Spindle`: each drives one piece of equipment and hides its protocol. |
| Reporting | `FB_ReportJob` aggregates a job into a `JobReport`; sinks decide where it goes. |
| Core | `FB_FunctionBlock_Base` (error state, reset contract), `Trace` (logging helper), `ErrorCodeToString`. |
| Simulation | `PRG_PlantSim` and `IO_Simulation` emulate the cylinder, the spindle and the linear axis, with fault injection. |

## 3. Design rules

These rules are applied consistently across the project. Each one exists because breaking it caused, or would have caused, a concrete problem.

**An interface only where there are several implementations.** The mover has two (cobot and linear axis), so the job manager depends on `I_Mover`. The spindle and the Z cylinder have one each, so they are used directly. Abstractions are added when variation exists, not in anticipation of it.

**Interfaces are named after a role, never a technology.** `I_Conveyor` was renamed `I_Mover` before the robot could replace it: an interface called "conveyor" forbids, by its name alone, putting a robot behind it.

**Dependencies are injected, not reached for.** Function blocks never read the I/O images or other global state; the only globals they use are configuration constants. `PLC_PRG` maps I/O images to function block inputs and outputs, and injects references once at start-up. Every function block can therefore be reasoned about, and tested, in isolation.

**Every device and job component is resettable and diagnosable.** These function blocks extend `FB_FunctionBlock_Base`, which implements `I_Resettable` and `I_Diagnosable`. `Reset` is abstract, so no component can forget to implement it. The job manager polls errors from all components every cycle; components never call the job manager. Report sinks are passive destinations and do not take part in this lifecycle.

**Methods are cyclic and non-blocking.** A command such as `MoveToPosition` is called every PLC cycle until it returns `TRUE`. Nothing waits inside a method; state lives in the function block, never in method-local variables.

**Every timeout has a meaning.** Each wait has its own timer and its own error code, so that a log entry says *why* the machine stopped, not only *that* it stopped.

## 4. Job state machine

| State | Action | Next |
|---|---|---|
| `Reset` | Reset every component | `Idle` when all report ready |
| `Idle` | Keep cylinder retracted, wait for START | `ReadingTargetPosition` |
| `ReadingTargetPosition` | Select next screw | `MovingToTargetPosition`, or `MovingToBase` if the recipe is exhausted |
| `MovingToTargetPosition` | `Mover.MoveToPosition(screw)` | `MovingZaxisToTool` |
| `MovingZaxisToTool` | Extend cylinder until the bit engages | `ProcessingTool`, or `MovingZaxisToBase` if the screw is not engaged (screw reported as failed) |
| `ProcessingTool` | Turn the spindle by the programmed angle | `MovingZaxisToBase` (screw reported as successful) |
| `MovingZaxisToBase` | Retract cylinder | `ReadingTargetPosition` |
| `MovingToBase` | `Mover.MoveToPosition(0)` | `Idle`, job report published |
| `Error` | All actuators disabled | `Reset` on STOP |

**STOP during a job means abort.** The partial report is published with `Completed = FALSE`, every component is reset, and the next START begins a new job from the first screw. A true pause/resume would require every component to restore a consistent state in the middle of a sequence; on a screwdriving cell, an interrupted part has to be inspected anyway.

## 5. PLC ↔ cobot interface contract

The PLC is a Modbus TCP client of the robot's built-in Modbus server.

| Signal | Direction | Type on the wire | Address | Meaning |
|---|---|---|---|---|
| `Cmd_Start` | PLC → robot | coil | 16 | Execute the move |
| `Sts_Done` | robot → PLC | coil | 17 | Move finished |
| `Cmd_Enable` | PLC → robot | coil | 18 | PLC in normal operation; robot may start a cycle |
| `Cmd_TargetPos01mm` | PLC → robot | register (WORD) | 128 | Target position, 0.1 mm, 0 to 5000 |
| `Sts_TargetPosEcho01mm` | robot → PLC | register (WORD) | 129 | Copy of register 128 as received by the robot |
| `Sts_Heartbeat` | robot → PLC | register (WORD) | 130 | Counter 0 to 1000, incremented every 50 ms |

The three registers are in the robot's general-purpose register area. The three coils, however, sit at the addresses of the robot's standard digital outputs DO0–DO2: the robot raises `Done` with `set_standard_digital_out(1, …)`. This works in simulation but is recorded as technical debt (§9), because on a real robot these signals would switch physical outputs.

All Modbus channels are cyclic at 100 ms. This period is a design assumption: the timeouts below are sized against it.

**Conventions.** Positions are absolute, in machine coordinates, in tenths of a millimetre. The PLC never knows the robot geometry: the robot converts the machine coordinate into its own frame through a taught Plane feature, `ScrewLine`, whose origin is machine position 0 and whose Y axis is taught along the screw line. The target pose is computed as `pose_trans(ScrewLine, p[0, position, 0, 0, 0, 0])`. Re-teaching that feature at commissioning is the only step needed if the robot is moved.

**Handshake.** The robot waits for `Start AND Enable`, reads the target, moves, raises `Done`, waits for `Start` to fall, then lowers `Done`. The fourth step guarantees that a new cycle never begins on a `Done` left over from the previous one. On the PLC side, `FB_Cobot` additionally refuses to start a cycle while `Done` is still high, which covers the case of a job aborted in the middle of a move.

**Echo: why it exists.** The first working version had a reproducible bug: the robot systematically executed the *previous* target. The PLC updated the target register and the start coil in the same cycle, but the Modbus stack sends them as two independent transactions, sampled at different instants. Whenever the PLC cycle fell between the two, the coil left with the new value and the register with the old one.

Reordering the channels could not fix it, because the race is between the PLC program and the Modbus stack, not between the channels. A delay would have fixed it only under an assumption about network timing. The retained solution removes the assumption: a robot thread continuously copies register 128 into register 129, and the PLC raises `Start` only once the echo equals the target it sent. The data is proven to have arrived before the trigger is emitted.

General rule: whenever data and its trigger travel on separate paths, either serialise them or have the data acknowledged.

**Heartbeat.** An echo alone cannot prove the robot program is alive: a stopped program leaves its registers frozen at their last, perfectly valid, values. The same robot thread increments a counter; the PLC considers the robot alive only while that value keeps changing, and raises `CobotNotConnected` after 500 ms without change (five Modbus periods). The heartbeat is unconditional: gating it on `Enable` would make "robot stopped" and "robot not enabled" indistinguishable, and would blind diagnostics exactly when the PLC is in error.

**Enable.** For the linear axis, `Enable()` switches the drive on. The PLC cannot power a robot through Modbus, so for the cobot `Enable()` *verifies* instead: it is where the heartbeat watchdog runs. Same contract, different implementation.

| Wait | Timeout | Error |
|---|---|---|
| Echo not returned | 2 s | `CobotNotConnected` |
| Heartbeat frozen | 500 ms (+1 s enable window) | `CobotNotConnected` |
| Move not finished | 30 s | `CobotMovementNotReached` |

## 6. Reporting

`FB_ReportJob` aggregates a job (counts, failed screws with their position, start and end time, job id, completed or aborted) into a `JobReport` structure, then hands it to every registered `I_ReportSink`. It never knows where the report goes: adding a destination means writing one function block and one line in `InitPous`.

Two kinds of output are deliberately kept apart. The per-event messages (job started, screw processed, error raised) are a **trace**, written directly to the PLC log through `Trace()`. The `JobReport` is a **business record** with potentially several consumers, and is the only one behind an abstraction.

Timestamps come from the real-time clock, in UTC, stored as `DT` and formatted only by each sink. The `JobId` is incremented at every job start and never reset by the application, so that consumers can de-duplicate a report delivered twice. It is not retained across a cold start of the PLC (§9).

## 7. Simulation and fault injection

`PRG_PlantSim` emulates the linear axis, the cylinder sensors and the spindle, with the same I/O images as real equipment. Each sensor can be forced to fail through a `SimFail_*` variable, which makes every timeout and error path testable from the watch window.

## 8. Key decisions

| Decision | Alternative considered | Reason |
|---|---|---|
| Robot replaces the linear axis, not the cylinder | Robot replaces the Z cylinder | A pneumatic cylinder is force-controlled and follows the screw as it sinks; a robot holding position is rigid. The software contract would have matched, the physical one would not. |
| Coordinate transform owned by the robot | Transform computed in the PLC | The PLC stays independent of the robot's geometry and mounting. |
| Echo acknowledgment | Channel reordering, fixed delay | The only option that does not depend on network timing. |
| Position resolution 0.1 mm on a 16-bit register | 32-bit value over two registers | Range 0–500 mm fits in 0–5000; one register, no word-order convention. |
| STOP aborts the job | Pause and resume | Much simpler to make correct; an interrupted part needs inspection anyway. |
| `JobReport` as a structure | Individual method parameters | Adding a field changes no interface signature. |
| `src/` generated from the XML export | Hand-maintained `.st` files | A hand-maintained copy drifts from the project at the first change. |

## 9. Technical debt and known limitations

Accepted, and listed so that nobody discovers them the hard way.

**Robot interface**

- **Handshake bits on physical output addresses.** Coils 16–18 are the robot's standard digital outputs DO0–DO2. They should move to the general-purpose bit area of the Modbus server, with `read_port_bit` / `write_port_bit` on the robot side.
- **No PLC → robot heartbeat.** If the PLC stops, the `Enable` coil stays frozen at `TRUE` and the robot keeps its authorisation.
- **Cobot watchdog runs only while enabled.** It lives in `Enable()`, which the job manager does not call during `Reset` and `Error`.
- **The robot does not re-validate the target range.** The PLC guarantees 0–500 mm; the robot trusts it.
- **`FB_Cobot.Reset()` returns immediately.** The risk of a stale `Done` is covered by a guard at the start of each move, not by the reset itself.
- **Robot installation not versioned, payload left at its default.** TCP and `ScrewLine` must be recreated from the values in the README; the payload was not set to the real mass of the cylinder and spindle.

**PLC**

- **Timeouts are literals** repeated in each function block and its `Reset`, rather than named constants.
- **Recipe hard-coded** as initial values of the screw table.
- **The log line does not show whether a job was completed or aborted.** `FB_LogSink` writes "finished" in both cases; the information is in `JobReport.Completed` for any other sink.
- **Negative angles lose their sign** in `FB_Spindle` (`ABS`): whether −180° means "unscrew" is an open specification question.
- **`JobId` restarts at 1 after a cold start**, so de-duplication only holds within one PLC run.
- **A clock failure stops the machine.** `FB_ReportJob` raises an error when the real-time clock cannot be read, which puts the whole cell in `Error`. Whether a reporting problem should stop production is an open design question.
- **Timestamps have one-second resolution.**

**Scope**

- **Modbus signals are not safety functions.** Emergency stop and safeguarding would go through the robot's safety I/O in a real cell.
- **No operator panel.** Start and stop are written from the CODESYS watch window. An HMI would only have to drive the two inputs of `FB_UserInterface`.
- **Simulation only.** No real hardware; the NTP configuration of a physical controller is a commissioning item.

## 10. Next steps

- Move the handshake bits to the general-purpose area of the robot's Modbus server.
- Publish the job report over MQTT through a new `FB_MqttSink`, with a Last Will to expose the machine's online state.
- Add a PLC → robot heartbeat, so that the robot stops when the PLC disappears.
- Load the recipe from a file or a supervisory system instead of initial values.
- Run URSim in the official Docker image, with the programs folder mounted from the repository, so the demo starts with a single command.
