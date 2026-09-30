// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION ErrorCodeToString : STRING
VAR_INPUT
	Code : ErrorCode;
END_VAR

CASE Code OF
	ErrorCode.NoError :
		ErrorCodeToString := 'No Error';
	ErrorCode.EnablementError:
		ErrorCodeToString := 'Enablement Error';
	ErrorCode.ScrewNotReleased:
		ErrorCodeToString := 'Screw Not Released';
	ErrorCode.TargetNotReached:
		ErrorCodeToString := 'Target Not Reached';
	ErrorCode.SpindleError:
		ErrorCodeToString := 'Spindle Error';
	ErrorCode.CobotNotConnected:
		ErrorCodeToString := 'Cobot Not Connected';
	ErrorCode.CobotMovementNotReached:
		ErrorCodeToString := 'Cobot Movement Not Reached';
	ErrorCode.RtcNotAvailable:
		ErrorCodeToString := 'Rtc Not Available';
ELSE
		ErrorCodeToString := 'Unknown Error';	
END_CASE

END_FUNCTION
