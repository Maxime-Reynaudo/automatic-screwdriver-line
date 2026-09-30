// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION Trace : BOOL
VAR_INPUT
	Severity : UDINT;   // LogClass.LOG_INFO / LOG_WARNING / LOG_ERROR
	Msg : STRING(255);
END_VAR

LogAdd(
	hLogger   := CmpLog.LogConstants.LOG_STD_LOGGER,
	stCmpName := Machine_Constants.LOG_COMPONENT_NAME,
	diClassID := UDINT_TO_DINT(Severity),
	diErrorID := 0,
	diInfoID  := 0,
	stInfo    := Msg
);

Trace := TRUE;

END_FUNCTION
