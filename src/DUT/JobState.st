// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

{attribute 'qualified_only'}
{attribute 'strict'}
TYPE JobState :
(
	Idle := 1,
	Reset,
	ReadingTargetPosition,
	MovingToTargetPosition,
	MovingToBase,
	MovingZaxisToTool,
	ProcessingTool,
	MovingZaxisToBase,
	Error
);
END_TYPE
