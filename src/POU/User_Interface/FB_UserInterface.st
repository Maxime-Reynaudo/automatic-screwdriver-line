// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_UserInterface EXTENDS FB_FunctionBlock_Base
VAR_INPUT
	StartRequest : BOOL;
	StopRequest : BOOL;
END_VAR
VAR
	_Start_Trig : R_TRIG;
	_Stop_Trig : R_TRIG;
END_VAR


METHOD Reset : BOOL

ClearError();
Reset := TRUE;
END_METHOD


METHOD IsStartRequired : BOOL

_Start_Trig(CLK := StartRequest);
IsStartRequired := _Start_Trig.Q;
END_METHOD


METHOD IsStopRequired : BOOL

_Stop_Trig(CLK := StopRequest);
IsStopRequired := _Stop_Trig.Q;
END_METHOD

END_FUNCTION_BLOCK
