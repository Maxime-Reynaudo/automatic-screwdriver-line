// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

PROGRAM PLC_PRG
VAR
	_InitDone : BOOL;
	_JobManager : FB_JobManager;
	_UserInterface : FB_UserInterface;
	_JobSelector : FB_JobSelector;
	_Conveyor : FB_ConveyorElectrical;
	_Cobot : FB_Cobot;
	_zAxis : FB_zAxis;
	_Spindle : FB_Spindle;
	_ReportJob : FB_ReportJob;
	_LogSink : FB_LogSink;
END_VAR

IF NOT _InitDone THEN
	_InitDone := InitPous();
END_IF


_JobManager.RunJob();


//I/O's connection: Machine -> Material
//For Conveyor:
IO_Simulation.MoverEnable := _Conveyor.MoverEnable;
IO_Simulation.MoverExecuteFor :=  _Conveyor.MoverExecuteFor;
IO_Simulation.MoverExecuteBac :=  _Conveyor.MoverExecuteBac;
// For Robot:
IO_Cobot.Cmd_TargetPos01mm := INT_TO_WORD(_Cobot.MoverTarget);   // 0..5000: no sign issue
IO_Cobot.Cmd_Start := _Cobot.MoverExecute;
IO_Cobot.Cmd_Enable := _Cobot.MoverEnable;
// For Z valve
IO_Simulation.zValve := _zAxis.zValve;
// For Spindle
IO_Simulation.SpindleEnable := _Spindle.SpindleEnable;
IO_Simulation.SpindleExecute := _Spindle.SpindleExecute;
IO_Simulation.SpindleExecuteTime := _Spindle.SpindleExecuteTime;

// Simulation
PRG_PlantSim();

//I/O's connection: Material -> Machine
//For Conveyor:
_Conveyor.MoverActPos := IO_Simulation.MoverActPos;
_Conveyor.MoverReady := IO_Simulation.MoverReady; 
// For cobot:
_Cobot.MoverPosEcho := WORD_TO_INT(IO_Cobot.Sts_TargetPosEcho01mm);
_Cobot.MoverDone := IO_Cobot.Sts_Done;
_Cobot.MoverHeartbeat := WORD_TO_INT(IO_Cobot.Sts_Heartbeat);
// For Z valve
_zAxis.ScrewEngaged := IO_Simulation.ScrewEngaged;
_zAxis.ScrewReleased := IO_Simulation.ScrewReleased;
_zAxis.zDown := IO_Simulation.zDown;
// For Spindle
_Spindle.SpindleReady := IO_Simulation.SpindleReady;
_Spindle.SpindleDone := IO_Simulation.SpindleDone;


METHOD PRIVATE InitPous : BOOL
VAR
	_Mover : I_Mover;
END_VAR

// Injection of dependencies
IF Machine_Constants.USE_COBOT THEN
	_Mover := _Cobot;
ELSE
	_Mover := _Conveyor;
END_IF

_ReportJob.AddSink(_LogSink);

InitPous := _JobManager.Init(
	UserInterface := _UserInterface,
	JobSelector := _JobSelector,
	Mover:= _Mover,
	zAxis := _zAxis,
	Spindle := _Spindle,
	ReportJob := _ReportJob);
END_METHOD

END_PROGRAM
