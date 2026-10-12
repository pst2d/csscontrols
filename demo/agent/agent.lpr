program agent;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  Interfaces, Forms, csstailwind, agentmain;

begin
  CSSTailwindEnable;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TAgentForm, AgentForm);
  Application.Run;
end.
