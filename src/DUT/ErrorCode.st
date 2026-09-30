// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

{attribute 'qualified_only'}
{attribute 'strict'}
TYPE ErrorCode :
(
	NoError := 0,
	EnablementError,
	ScrewNotReleased,
	TargetNotReached,
	SpindleError,
	CobotNotConnected,
	CobotMovementNotReached,
	RtcNotAvailable
);
END_TYPE
