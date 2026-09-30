// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_JobSelector EXTENDS FB_FunctionBlock_Base
VAR_INPUT
	ArrScrews : ScrewList := [
		(PositionMm := 100.0, AngleDeg := 90),
		(PositionMm := 130.0, AngleDeg := 600),
		(PositionMm := 185.0, AngleDeg := -180),
		(PositionMm := 27.0, AngleDeg := 360),
		(PositionMm := 300.0, AngleDeg := 720)
	];
END_VAR
VAR_OUTPUT
	CurrentScrew : Screw;
	Job_Done : BOOL;
END_VAR
VAR
	_TableIndex : INT := 0;
END_VAR


METHOD Reset : BOOL

ClearError();
_TableIndex := 0;
Job_Done := FALSE;

Reset := TRUE;
END_METHOD


METHOD ReturnScrew : BOOL

ReturnScrew := FALSE;


IF SelectNextScrew() THEN
	CurrentScrew := ArrScrews[_TableIndex];
	ReturnScrew := TRUE;
ELSE
	CurrentScrew.PositionMm := 0.0;
	CurrentScrew.AngleDeg := 0;
END_IF
END_METHOD


METHOD SelectNextScrew : BOOL

// Method responsible for incrementing _TableIndex
SelectNextScrew := FALSE;
Job_Done := FALSE;
IF _TableIndex < UPPER_BOUND(ArrScrews, 1) THEN
	_TableIndex := _TableIndex + 1;
	SelectNextScrew := TRUE;
ELSE
	_TableIndex := 0;
	Job_Done := TRUE;
END_IF
END_METHOD

END_FUNCTION_BLOCK
