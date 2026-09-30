// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

TYPE JobReport :
STRUCT
	JobId : UDINT;
	StartedAt : DT;
	FinishedAt : DT;
	ScrewsOk : INT;
	ScrewsFailed : INT;
	FailedScrews : ScrewList;
	Completed : BOOL;   // TRUE = all screws processed, FALSE = aborted by operator
END_STRUCT
END_TYPE
