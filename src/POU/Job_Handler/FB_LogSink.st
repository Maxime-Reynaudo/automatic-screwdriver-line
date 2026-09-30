// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

FUNCTION_BLOCK FB_LogSink IMPLEMENTS I_ReportSink


METHOD PublishReport : BOOL
VAR_INPUT
	Report : JobReport;
END_VAR
VAR
	_msg : STRING(255);
END_VAR

_msg := CONCAT('Job ', UDINT_TO_STRING(Report.JobId));
_msg := CONCAT(_msg,   ' finished: ');
_msg := CONCAT(_msg,   INT_TO_STRING(Report.ScrewsOk));
_msg := CONCAT(_msg,   ' ok, ');
_msg := CONCAT(_msg,   INT_TO_STRING(Report.ScrewsFailed));
_msg := CONCAT(_msg,   ' failed');

Trace(CmpLog.LogClass.LOG_INFO, _msg);

PublishReport := TRUE;
END_METHOD

END_FUNCTION_BLOCK
