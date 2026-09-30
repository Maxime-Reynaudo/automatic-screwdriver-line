// Generated from Automatic_ScrewDriver_Line.xml by tools/export_st.py - do not edit.
// The CODESYS project is the source of truth.

PROGRAM PRG_PlantSim
VAR
	_Increment : REAL := 1;
	_ZAxisMovingTimeUp : TON;
	_ZAxisMovingTimeDown : TON;
	_SpindleMovingTime : TON;
END_VAR

// Conveyor
IO_Simulation.MoverReady := IO_Simulation.MoverEnable
                                   AND NOT IO_Simulation.SimFail_MoverReady;
IF IO_Simulation.MoverExecuteFor AND IO_Simulation.MoverEnable
   AND NOT IO_Simulation.SimFail_MoverBlocked THEN
    IO_Simulation.MoverActPos := IO_Simulation.MoverActPos + _Increment;
ELSIF IO_Simulation.MoverExecuteBac AND IO_Simulation.MoverEnable
   AND NOT IO_Simulation.SimFail_MoverBlocked THEN
    IO_Simulation.MoverActPos := IO_Simulation.MoverActPos - _Increment;
END_IF

// Z Axis
_ZAxisMovingTimeUp(IN := IO_Simulation.zValve, PT := T#1S);
IO_Simulation.ScrewEngaged := _ZAxisMovingTimeUp.Q
                                     AND NOT IO_Simulation.SimFail_ScrewEngaged;
_ZAxisMovingTimeDown(IN := NOT IO_Simulation.zValve, PT := T#1S);
IO_Simulation.ScrewReleased := _ZAxisMovingTimeDown.Q
                                      AND NOT IO_Simulation.SimFail_ScrewReleased;
// zDown is not filtered: the cylinder physically retracts even if the bit stays engaged
IO_Simulation.zDown := _ZAxisMovingTimeDown.Q;

// Spindle
IO_Simulation.SpindleReady := IO_Simulation.SpindleEnable;
_SpindleMovingTime(IN := IO_Simulation.SpindleExecute
                         AND IO_Simulation.SpindleEnable,
                   PT := IO_Simulation.SpindleExecuteTime);
IO_Simulation.SpindleDone := _SpindleMovingTime.Q
                                    AND NOT IO_Simulation.SimFail_SpindleDone;

END_PROGRAM
