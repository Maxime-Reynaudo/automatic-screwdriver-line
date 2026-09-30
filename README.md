# Automatic Screwdriver Line

**PLC ↔ collaborative robot integration in IEC 61131-3 (CODESYS) and Universal Robots PolyScope.**

<!-- Add a screenshot or a short GIF of the cell running, then uncomment:
![Cell running in simulation: CODESYS WebVisu and URSim](docs/img/demo.gif)
-->

A small automated screwdriving cell, built end to end as a self-directed engineering exercise: an object-oriented PLC program orchestrates a Universal Robots cobot over Modbus TCP, a pneumatic Z cylinder and a screwdriving spindle, and publishes a report for every job.

The point of the project is less the cell itself than **how it is built**: explicit interfaces, dependency injection, a PLC ↔ robot contract that survives network timing, and a design where the robot can replace a linear axis without changing a single line of the job orchestration.

> Author: Maxime Reynaudo · September 2026 · Simulation only (soft PLC + URSim)

---

## The cell

The workpiece is fixed. A UR cobot carries a pneumatic cylinder on its flange, and a screwdriving spindle is mounted on the cylinder.

For each screw of the recipe:

1. the cobot positions the head along the screw line, a direction taught once as a reference frame on the robot;
2. the cylinder extends until the bit engages the screw;
3. the spindle turns by the programmed angle;
4. the cylinder retracts.

At the end of the job, the robot returns to the origin and a job report is published.

An alternative configuration replaces the cobot with a simulated electric linear axis. Switching between the two is a single constant: the job logic is identical.

## What this project demonstrates

- **Object-oriented IEC 61131-3**: function blocks with inheritance, abstract methods, interfaces and dependency injection.
- **Substitution by design**: `I_Mover` has two implementations (`FB_Cobot`, `FB_ConveyorElectrical`); the job manager only knows the interface.
- **A robust PLC ↔ robot contract over Modbus TCP**: 4-step handshake, an echo mechanism that makes a stale-data race impossible, and a heartbeat watchdog.
- **Separation of trace and business output**: diagnostic traces go to the PLC log; the job report goes to pluggable destinations (`I_ReportSink`).
- **Testability without hardware**: a plant simulation with fault injection for every sensor.

The design decisions, the PLC ↔ robot contract and the known limitations are documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Reading the code

**Start in [`src/`](src).** It contains the whole PLC program as Structured Text, one file per object, laid out like the folders of the CODESYS project.

`src/` is generated from the PLCopen XML export by [`tools/export_st.py`](tools/export_st.py), so that the code can be read and reviewed directly on GitHub. The CODESYS project remains the source of truth: do not edit `src/` by hand.

The robot program is in [`cobot/ScrewLineProgram.script`](cobot/ScrewLineProgram.script) (URScript) and [`cobot/ScrewLineProgram.txt`](cobot/ScrewLineProgram.txt) (PolyScope program tree).

## Repository layout

```
src/     PLC code as Structured Text, one file per object (generated, read-only)
plc/     CODESYS project (.project) and its PLCopen XML export
cobot/   PolyScope program (.urp), generated URScript (.script), program tree (.txt)
docs/    Architecture, design decisions, interface contract, technical debt
tools/   export_st.py (generates src/) and commit.sh (export check, generation, commit)
```

The `.project` and `.urp` files are compressed binaries. The `.xml` export and the `.script` file are their full-fidelity text counterparts, versioned alongside them.

## Requirements

| Component | Version used |
|---|---|
| CODESYS Development System | V3.5 SP21 Patch 5 |
| PLC runtime | CODESYS Control Win V3 x64 (soft PLC) |
| Robot simulator | URSim 5.25.2 (PolyScope 5), VirtualBox VM |
| Network | VirtualBox host-only network, robot at `192.168.56.101` |
| CODESYS libraries | ModbusTCP, SysTimeRtc, CmpLog, Visualization |
| Tooling | Python 3.8+, Git Bash (for `tools/commit.sh` on Windows) |

## Running the demo

**Robot side**

1. Copy the content of `cobot/` into the PolyScope programs folder of the VM.
2. Recreate the installation, which is not versioned (see limitations). The values below are taken from the generated `ScrewLineProgram.script`:

   | Setting | Value |
   |---|---|
   | TCP | X = 0, Y = 0, Z = 100 mm, no rotation |
   | Plane feature `ScrewLine`, in the base frame | X = −293.49 mm, Y = −24.78 mm, Z = 662.62 mm, RX = 0, RY = 0, RZ = 1.7850 rad |

   The origin of `ScrewLine` is machine position 0. The robot moves the tool along the **Y axis** of this feature, which is taught along the screw line.
3. Load `ScrewLineProgram` and start it. The program waits for the PLC.

**PLC side**

1. Open `plc/Automatic_ScrewDriver_Line.project`.
2. Check `Machine_Constants.USE_COBOT`: `TRUE` for the cobot, `FALSE` for the simulated linear axis.
3. Start CODESYS Control Win, log in, download and run.
4. Open the operator panel at `http://localhost:8080/webvisu.htm` and press **START**.

Each screw is traced in the PLC log, and the job ends with a summary line such as:

```
Job 1 completed: 5 ok, 0 failed
```

A job stopped by the operator is reported as `aborted`, with the screws processed so far.

**Fault injection**

The `IO_Simulation` list exposes `SimFail_*` variables (spindle never done, screw not released, axis blocked, …). Forcing one of them from the watch window exercises the corresponding timeout and error path.

## Development workflow

After any change in CODESYS:

1. **Project → Export PLCopenXML…**, all objects, to `plc/Automatic_ScrewDriver_Line.xml`.
2. From the repository root, in Git Bash:

   ```bash
   ./tools/commit.sh "Describe the change"
   ```

   The script refuses to run if the `.project` is newer than the XML export, regenerates `src/`, then commits and pushes. To regenerate `src/` alone:

   ```bash
   python tools/export_st.py plc/Automatic_ScrewDriver_Line.xml src
   ```

A change to the PLC ↔ robot interface is committed together with the updated robot files and documentation, so that every commit contains a PLC and a robot program that work together.

## Known limitations

- **The robot installation file is not versioned.** The TCP and the `ScrewLine` feature must be recreated from the values above.
- **The three handshake bits use the addresses of the robot's standard digital outputs DO0–DO2.** Harmless in simulation, but on a real robot they would switch physical outputs: they belong in the general-purpose area of the robot's Modbus server.
- Everything runs in simulation. The Modbus signals between PLC and robot are functional logic, **not safety functions**: a real cell would route emergency stop and safeguarding through the robot's safety I/O.
- The job report is currently published to the PLC log only; an MQTT destination is the planned next step.

The full list of limitations and accepted technical debt is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#9-technical-debt-and-known-limitations).

---

© 2026 Maxime Reynaudo. All rights reserved.
