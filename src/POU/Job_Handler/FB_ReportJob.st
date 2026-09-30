// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_ReportJob EXTENDS FB_FunctionBlock_Base
VAR
	_NbSuccess : INT := 0;
	_NbFail : INT := 0;
	_FailedScrews : ScrewList;
	_SuccessfulScrews : ScrewList;
	_JobDone : BOOL;
	_JobId : UDINT;
	_StartedAt : DT;
	_FinishedAt : DT;
	_Sinks : ARRAY[1..3] OF I_ReportSink;
	_EmptyScrewList : ScrewList;
END_VAR


METHOD Reset : BOOL

ClearError();
_NbSuccess := 0;
_NbFail := 0;
_JobDone := FALSE;

_FailedScrews     := _EmptyScrewList;
_SuccessfulScrews := _EmptyScrewList;

Reset := TRUE;
END_METHOD


METHOD JobEnd : BOOL

_FinishedAt := Now();

Trace(CmpLog.LogClass.LOG_INFO, 'Job Done');

JobEnd := SendReportToSinks(Completed := TRUE);
END_METHOD


METHOD SuccessScrew : BOOL
VAR_INPUT
	SuccessfulScrew : Screw;
END_VAR

SuccessScrew := FALSE;

IF _NbSuccess < UPPER_BOUND(_SuccessfulScrews, 1) THEN
	_NbSuccess := _NbSuccess + 1;
	_SuccessfulScrews[_NbSuccess] := SuccessfulScrew;
	SuccessScrew := TRUE;
END_IF

Trace(CmpLog.LogClass.LOG_INFO,
        CONCAT('Screw successfully processed at position ', REAL_TO_STRING(SuccessfulScrew.PositionMm)));
END_METHOD


METHOD FailScrew : BOOL
VAR_INPUT
	FailedScrew : Screw;
END_VAR

FailScrew := FALSE;

IF _NbFail < UPPER_BOUND(_FailedScrews, 1) THEN
	_NbFail := _NbFail + 1;
	_FailedScrews[_NbFail] := FailedScrew;
	FailScrew := TRUE;
END_IF

Trace(CmpLog.LogClass.LOG_WARNING,
        CONCAT('Screw missed at position ', REAL_TO_STRING(FailedScrew.PositionMm)));
END_METHOD


METHOD JobStart : BOOL

_JobId      := _JobId + 1;
_StartedAt  := Now();
_FinishedAt := DT#1970-01-01-00:00:00;

Trace(CmpLog.LogClass.LOG_INFO, 'Job Started');

JobStart := TRUE;
END_METHOD


METHOD JobAborted : BOOL

_FinishedAt := Now();

Trace(CmpLog.LogClass.LOG_WARNING, 'Job Aborted');

JobAborted := SendReportToSinks(Completed := FALSE);
END_METHOD


METHOD AddSink : BOOL
VAR_INPUT
	Sink : I_ReportSink;
END_VAR
VAR
	_i : DINT;
END_VAR

AddSink := FALSE;

FOR _i := 1 TO UPPER_BOUND(_Sinks, 1) DO
	IF _Sinks[_i] = 0 THEN
		_Sinks[_i] := Sink;
		AddSink := TRUE;
		RETURN;
	END_IF
END_FOR
END_METHOD


METHOD SendReportToSinks : BOOL
VAR_INPUT
	Completed : BOOL;   // TRUE = job finished normally, FALSE = aborted by operator
END_VAR
VAR
	_report : JobReport;
	_i : DINT;
END_VAR

_report.JobId        := _JobId;
_report.StartedAt    := _StartedAt;
_report.FinishedAt   := _FinishedAt;
_report.ScrewsOk     := _NbSuccess;
_report.ScrewsFailed := _NbFail;
_report.FailedScrews := _FailedScrews;
_report.Completed := Completed;

SendReportToSinks := TRUE;

FOR _i := 1 TO UPPER_BOUND(_Sinks, 1) DO
	IF _Sinks[_i] <> 0 THEN
		IF NOT _Sinks[_i].PublishReport(_report) THEN
			SendReportToSinks := FALSE;
		END_IF
	END_IF
END_FOR
END_METHOD


METHOD Now : DT
VAR
	_sec : UDINT;
	_res : RTS_IEC_RESULT;
END_VAR

_sec := SysTimeRtcGet(_res);

IF _res = Errors.ERR_OK THEN
	Now := UDINT_TO_DT(_sec);
ELSE
	Now := DT#1970-01-01-00:00:00;
	RaiseError(ErrorCode.RtcNotAvailable);
END_IF
END_METHOD

END_FUNCTION_BLOCK
