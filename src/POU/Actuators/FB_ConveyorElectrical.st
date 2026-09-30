// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_ConveyorElectrical EXTENDS FB_FunctionBlock_Base IMPLEMENTS I_Mover
VAR_INPUT
	MoverActPos : REAL;
	MoverReady : BOOL;
END_VAR
VAR_OUTPUT
	MoverEnable : BOOL;
	MoverExecuteFor : BOOL;
	MoverExecuteBac : BOOL;
END_VAR
VAR
	_MoverTarget : REAL;
	_TimerEnablement : TON;
	_TimerMoveLinear : TON;
END_VAR


METHOD Reset : BOOL

ClearError();
Disable();
MoverExecuteFor := FALSE;
MoverExecuteBac := FALSE;
_MoverTarget :=  0.0;
_TimerEnablement(IN := FALSE, PT := T#1S);
_TimerMoveLinear(IN := FALSE, PT := T#100S);
Reset := TRUE;
END_METHOD


METHOD MoveToPosition : BOOL
VAR_INPUT
	Position : REAL;
END_VAR

MoveToPosition := FALSE;

_MoverTarget := Position;


IF _TimerMoveLinear.Q THEN
	RaiseError(ErrorCode.TargetNotReached);
ELSIF _MoverTarget - MoverActPos >= 1 THEN
	MoverExecuteFor := TRUE;
ELSIF _MoverTarget - MoverActPos <= -1 THEN
	MoverExecuteBac := TRUE;
ELSE
	MoveToPosition := TRUE;
	MoverExecuteFor := FALSE;
	MoverExecuteBac := FALSE;
END_IF

_TimerMoveLinear(IN := (MoverExecuteFor OR MoverExecuteBac), PT := T#100S);
END_METHOD


METHOD Enable : BOOL

Enable := FALSE;

MoverEnable := TRUE;
_TimerEnablement(IN := MoverEnable AND NOT MoverReady, PT := T#1S);

IF MoverReady THEN
	Enable := TRUE;
ELSIF _TimerEnablement.Q THEN
	RaiseError(ErrorCode.EnablementError);
END_IF
END_METHOD


METHOD Disable : BOOL

MoverEnable := FALSE;
Disable := TRUE;
END_METHOD

END_FUNCTION_BLOCK
