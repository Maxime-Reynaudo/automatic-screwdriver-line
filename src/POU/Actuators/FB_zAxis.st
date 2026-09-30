// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_zAxis EXTENDS FB_FunctionBlock_Base
VAR_INPUT
	zDown : BOOL;
	ScrewEngaged : BOOL;
	ScrewReleased : BOOL;
END_VAR
VAR_OUTPUT
	zValve : BOOL;
END_VAR
VAR
	_timerUp : TON;
	_timerDown : TON;
END_VAR


METHOD Reset : BOOL

ClearError();

zValve := FALSE;

IF zDown THEN
	Reset := TRUE;
END_IF

_timerUp(IN := FALSE, PT := T#5S);
_timerDown(IN := FALSE, PT := T#5S);
END_METHOD


METHOD Engage : ActionResult

Engage := ActionResult.Busy;
zValve := TRUE;

_timerUp(IN := zValve AND NOT ScrewEngaged, PT := T#5S);
_timerDown(IN := FALSE, PT := T#5S);

IF ScrewEngaged THEN
	Engage := ActionResult.Done;
ELSIF _timerUp.Q THEN
	Engage := ActionResult.Failed;
END_IF
END_METHOD


METHOD Retract : BOOL

Retract := FALSE;
zValve := FALSE;

_timerDown(IN := NOT zValve AND NOT (zDown AND ScrewReleased), PT := T#5S);
_timerUp(IN := FALSE, PT := T#5S);

IF zDown AND ScrewReleased THEN
    Retract := TRUE;
ELSIF _timerDown.Q THEN
	RaiseError(ErrorCode.ScrewNotReleased);
END_IF
END_METHOD

END_FUNCTION_BLOCK
