// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_JobManager EXTENDS FB_FunctionBlock_Base
VAR
	_InitDone : BOOL;
	_state : JobState;
	_ActiveError : ErrorCode;
	_Stop : BOOL;
	_Reseters : ARRAY[1..6] OF I_Resettable;
	_Diagnosable : ARRAY[1..6] OF I_Diagnosable;
	_i : DINT;
	_UserInterface : REFERENCE TO FB_UserInterface;
	_JobSelector : REFERENCE TO FB_JobSelector;
	_Mover : I_Mover;
	_zAxis : REFERENCE TO FB_zAxis;
	_Spindle : REFERENCE TO FB_Spindle;
	_ReportJob : REFERENCE TO FB_ReportJob;
	_SpindleOk : BOOL;
	_MoverOk : BOOL;
END_VAR


METHOD Reset : BOOL

ClearError();
Reset := TRUE;
END_METHOD


METHOD RunJob : BOOL

IF NOT _InitDone THEN
	RETURN;
END_IF

_ActiveError := CheckErrors();
_Stop := _UserInterface.IsStopRequired();
		  
IF _ActiveError <> ErrorCode.NoError AND _state <> JobState.Reset THEN
    _state := JobState.Error;
END_IF

IF _state <> JobState.Reset AND _state <> JobState.Error THEN
    EnableAll();
ELSE
    DisableAll();
END_IF

CASE _state OF
	JobState.Reset :
		IF ResetAll() THEN
			_state := JobState.Idle;
		END_IF
	JobState.Idle:
		IF _Stop THEN
			_state := JobState.Reset;
		ELSIF _zAxis.Retract() THEN
        	IF _UserInterface.IsStartRequired() THEN
            _ReportJob.Reset();
			_ReportJob.JobStart();
            _state := JobState.ReadingTargetPosition;
        	END_IF
    	END_IF
	JobState.ReadingTargetPosition :
		IF _JobSelector.ReturnScrew() THEN
			_state:= JobState.MovingToTargetPosition;
		ELSE
			_state := JobState.MovingToBase;
		END_IF
	JobState.MovingToTargetPosition :
		IF _Mover.MoveToPosition(_JobSelector.CurrentScrew.PositionMm) THEN
			_state:= JobState.MovingZaxisToTool;
		END_IF
	JobState.MovingZaxisToTool :
		    CASE _zAxis.Engage() OF
        		ActionResult.Done:
            		_state := JobState.ProcessingTool;
				ActionResult.Failed:
            		_ReportJob.FailScrew(_JobSelector.CurrentScrew);
					_state := JobState.MovingZaxisToBase;
    		END_CASE
	JobState.ProcessingTool :
		IF _Spindle.ProcessTool(_JobSelector.CurrentScrew.AngleDeg) THEN		
			_ReportJob.SuccessScrew(_JobSelector.CurrentScrew);
			_state:= JobState.MovingZaxisToBase;
		END_IF
	JobState.MovingZaxisToBase :
		IF _zAxis.Retract() THEN
			_state:= JobState.ReadingTargetPosition;
		END_IF
	JobState.MovingToBase :
		IF _Mover.MoveToPosition(0)  THEN
			_state := JobState.Idle;
			_ReportJob.JobEnd();
		END_IF
	JobState.Error :
		IF _Stop THEN
			_state := JobState.Reset;
		END_IF
END_CASE

// Stop during a job = abort: publish the partial report, then reset every component.
// The next Start begins a fresh job from the first screw.
IF _Stop
   AND _state <> JobState.Idle
   AND _state <> JobState.Reset
   AND _state <> JobState.Error THEN
	_ReportJob.JobAborted();
	_state := JobState.Reset;
END_IF
END_METHOD


METHOD Init : BOOL
VAR_INPUT
	UserInterface : REFERENCE TO FB_UserInterface;
	JobSelector : REFERENCE TO FB_JobSelector;
	Mover : I_Mover;
	zAxis : REFERENCE TO FB_zAxis;
	Spindle : REFERENCE TO FB_Spindle;
	ReportJob : REFERENCE TO FB_ReportJob;
END_VAR

_UserInterface REF= UserInterface;
_JobSelector REF= JobSelector;
_Mover := Mover;
_zAxis REF= zAxis;
_Spindle REF= Spindle;
_ReportJob REF= ReportJob;

// Reseters
_Reseters[1] := _UserInterface;
_Reseters[2] := _JobSelector;
_Reseters[3] := _Mover;
_Reseters[4] := _zAxis;
_Reseters[5] := _Spindle;
_Reseters[6] := _ReportJob;

// Diagnosable
_Diagnosable[1] := _UserInterface;
_Diagnosable[2] := _JobSelector;
_Diagnosable[3] := _Mover;
_Diagnosable[4] := _zAxis;
_Diagnosable[5] := _Spindle;
_Diagnosable[6] := _ReportJob;

_InitDone := TRUE;
Init := TRUE;
END_METHOD


METHOD DisableAll : BOOL

_SpindleOk := _Spindle.Disable();
_MoverOk   := _Mover.Disable();
DisableAll := _SpindleOk AND _MoverOk;
END_METHOD


METHOD EnableAll : BOOL

_SpindleOk := _Spindle.Enable();
_MoverOk   := _Mover.Enable();
EnableAll  := _SpindleOk AND _MoverOk;
END_METHOD


METHOD ResetAll : BOOL

ResetAll := TRUE;

FOR _i := 1 TO UPPER_BOUND(_Reseters, 1) DO
    IF NOT _Reseters[_i].Reset() THEN
        ResetAll := FALSE;
    END_IF
END_FOR
END_METHOD


METHOD CheckErrors : ErrorCode

CheckErrors := ErrorCode.NoError;

FOR _i := 1 TO UPPER_BOUND(_Diagnosable, 1) DO
    IF _Diagnosable[_i].GetError() <> ErrorCode.NoError
       AND CheckErrors = ErrorCode.NoError THEN
        CheckErrors := _Diagnosable[_i].GetError();
    END_IF
END_FOR
END_METHOD

END_FUNCTION_BLOCK
