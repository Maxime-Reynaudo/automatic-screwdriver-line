// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_Cobot EXTENDS FB_FunctionBlock_Base IMPLEMENTS I_Mover
VAR_INPUT
	MoverPosEcho : INT;   // Echo to ensure synchronisation with MoverTarget
	MoverDone : BOOL;
	MoverHeartbeat : INT;   // Watchdog counter to make sure Cobot connection is not lost
END_VAR
VAR_OUTPUT
	MoverEnable : BOOL;
	MoverTarget : INT;
	MoverExecute : BOOL;
END_VAR
VAR
	_state : MoverState := MoverState.Idle;
	_TimerEcho : TON;
	_TimerMove : TON;
	_TimerEnablement : TON;
	_LastHeartbeat : INT;
	_HbTimer : TON;
	_Alive : BOOL;
	_HbChanged : BOOL;
END_VAR


METHOD Reset : BOOL

ClearError();
Disable();
MoverTarget :=  0;
_state := MoverState.Idle;
_TimerEnablement(IN := FALSE, PT := T#1S);
_TimerEcho(IN := FALSE, PT := T#2S);
_TimerMove(IN := FALSE, PT := T#30S);
_HbTimer(IN := FALSE, PT := T#500MS);

Reset := TRUE;
END_METHOD


METHOD MoveToPosition : BOOL
VAR_INPUT
	Position : REAL;
END_VAR

MoveToPosition := FALSE;

CASE _state OF

	MoverState.Idle:
		// Never start a cycle while the robot still asserts Done from a previous one
		IF NOT MoverDone THEN
			MoverTarget  := REAL_TO_INT(Position * 10.0);
			MoverExecute := FALSE;
			_state := MoverState.WaitingEcho;
		END_IF

	MoverState.WaitingEcho:
		IF MoverPosEcho = MoverTarget THEN
			MoverExecute := TRUE;
			_state := MoverState.Moving;
		ELSIF _TimerEcho.Q THEN
			RaiseError(ErrorCode.CobotNotConnected);
		END_IF

	MoverState.Moving:
		IF MoverDone THEN
			MoverExecute := FALSE;
			_state := MoverState.WaitingDoneReleased;
		ELSIF _TimerMove.Q THEN
			RaiseError(ErrorCode.CobotMovementNotReached);
		END_IF

	MoverState.WaitingDoneReleased:
		IF NOT MoverDone THEN
			MoveToPosition := TRUE;
			_state := MoverState.Idle;
		END_IF

END_CASE

_TimerEcho(IN := (_state = MoverState.WaitingEcho), PT := T#2S);
_TimerMove(IN := (_state = MoverState.Moving), PT := T#30S);
END_METHOD


METHOD Enable : BOOL

_HbChanged := (MoverHeartbeat <> _LastHeartbeat);
_LastHeartbeat := MoverHeartbeat;
_HbTimer(IN := NOT _HbChanged, PT := T#500MS);
_Alive := NOT _HbTimer.Q;

Enable := FALSE;
MoverEnable := TRUE;

_TimerEnablement(IN := NOT _Alive, PT := T#1S);

IF _Alive THEN
	Enable := TRUE;
ELSIF _TimerEnablement.Q THEN
	RaiseError(ErrorCode.CobotNotConnected);
END_IF
END_METHOD


METHOD Disable : BOOL

MoverEnable  := FALSE;
MoverExecute := FALSE;
Disable := TRUE;
END_METHOD

END_FUNCTION_BLOCK
