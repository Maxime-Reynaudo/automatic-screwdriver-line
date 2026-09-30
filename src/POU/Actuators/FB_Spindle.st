// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_Spindle EXTENDS FB_FunctionBlock_Base IMPLEMENTS I_Actuator
VAR_INPUT
	SpeedDegPerSec : DINT := Machine_Constants.TOOL_SPEED;
	SpindleReady : BOOL;
	SpindleDone : BOOL;
END_VAR
VAR_OUTPUT
	SpindleEnable : BOOL;
	SpindleExecute : BOOL;
	SpindleExecuteTime : TIME;
END_VAR
VAR
	_AngleTarget : DINT;
	_Started : BOOL;
	_TimerEnablement : TON;
	_TimerProcessTool : TON;
END_VAR


METHOD Reset : BOOL

ClearError();
Disable();
SpindleEnable := FALSE;
SpindleExecute := FALSE;
SpindleExecuteTime := T#0S;
_AngleTarget := 0;
_Started := FALSE;
_TimerEnablement(IN := FALSE, PT := T#1S);
_TimerProcessTool(IN := FALSE, PT := T#20S);
Reset := TRUE;
END_METHOD


METHOD ProcessTool : BOOL
VAR_INPUT
	Angle : DINT;
END_VAR

ProcessTool := FALSE;
_TimerProcessTool(IN := SpindleExecute AND NOT SpindleDone, PT := T#20S);
_AngleTarget := ABS(Angle); 

IF NOT _Started AND SpindleEnable THEN
	SpindleExecuteTime := DINT_TO_TIME(_AngleTarget*1000/SpeedDegPerSec);
	SpindleExecute := TRUE;
	_Started := TRUE;
ELSIF SpindleDone THEN
	SpindleExecute := FALSE;
	_Started := FALSE;
	ProcessTool := TRUE;
ELSIF _TimerProcessTool.Q THEN
	RaiseError(ErrorCode.SpindleError);
END_IF
END_METHOD


METHOD Enable : BOOL

Enable := FALSE;

SpindleEnable := TRUE;
_TimerEnablement(IN := SpindleEnable AND NOT SpindleReady, PT := T#1S);

IF SpindleReady THEN
	Enable := TRUE;
ELSIF _TimerEnablement.Q THEN
	RaiseError(ErrorCode.EnablementError);
END_IF
END_METHOD


METHOD Disable : BOOL

SpindleEnable := FALSE;
Disable := TRUE;
END_METHOD

END_FUNCTION_BLOCK
