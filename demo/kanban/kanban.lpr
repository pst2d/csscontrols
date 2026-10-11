program kanban;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  Interfaces, Forms, csstailwind, kanbanmain;

begin
  CSSTailwindEnable;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TKanbanForm, KanbanForm);
  Application.Run;
end.
