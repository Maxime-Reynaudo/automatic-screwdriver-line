// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

{attribute 'qualified_only'}
VAR_GLOBAL
	Cmd_Enable : BOOL;   // Type Modbus: coil, Address: 18
	Cmd_Start : BOOL;   // Type Modbus: coil, Address: 16
	Cmd_TargetPos01mm : WORD;   // Type Modbus: register, Address: 128, unit 0.1mm (to keep .1mm resolution from Position)
	Sts_Done : BOOL;   // Type Modbus: coil, Address: 17
	Sts_TargetPosEcho01mm : WORD;   // Type Modbus: register, Address: 129
	Sts_Heartbeat : WORD;   // Type Modbus: register, Address: 130
END_VAR
