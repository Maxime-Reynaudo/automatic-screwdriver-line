// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

{attribute 'qualified_only'}
VAR_GLOBAL
	// Mover
	// Outputs: PLC to Machine
	MoverEnable : BOOL;
	MoverExecuteFor : BOOL;
	MoverExecuteBac : BOOL;
	MoverActPos : REAL;   // Inputs: Machine to PLC
	MoverReady : BOOL;
	// Z Axis
	// Outputs: PLC to Machine
	zValve : BOOL;
	zDown : BOOL;   // Inputs: Machine to PLC
	ScrewEngaged : BOOL;
	ScrewReleased : BOOL;
	// Spindle
	// Outputs: PLC to Machine
	SpindleEnable : BOOL;
	SpindleExecute : BOOL;
	SpindleExecuteTime : TIME;
	SpindleReady : BOOL;   // Inputs: Machine to PLC
	SpindleDone : BOOL;
	SimFail_ScrewEngaged : BOOL;   // Z axis rises but the bit never engages the screw
	SimFail_ScrewReleased : BOOL;   // bit stays stuck in the screw head
	SimFail_SpindleDone : BOOL;   // spindle never reports completion
	SimFail_MoverReady : BOOL;   // drive never confirms torque
	SimFail_MoverBlocked : BOOL;   // axis is commanded but does not move
END_VAR
