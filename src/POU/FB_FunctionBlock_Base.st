// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK ABSTRACT FB_FunctionBlock_Base IMPLEMENTS I_Resettable, I_Diagnosable
VAR
	_Error : ErrorCode;
END_VAR


METHOD ABSTRACT Reset : BOOL
END_METHOD


METHOD RaiseError : BOOL
VAR_INPUT
	Error : ErrorCode;
END_VAR

RaiseError := FALSE;

IF _Error = ErrorCode.NoError THEN
	_Error := Error;
	Trace(CmpLog.LogClass.LOG_ERROR, ErrorCodeToString(Error));
	RaiseError := TRUE;
END_IF
END_METHOD


METHOD GetError : ErrorCode

GetError := _Error;
END_METHOD


METHOD ClearError : BOOL

_Error := ErrorCode.NoError;
ClearError := TRUE;
END_METHOD


METHOD HasError : BOOL

HasError := (_Error <> ErrorCode.NoError);
END_METHOD

END_FUNCTION_BLOCK
