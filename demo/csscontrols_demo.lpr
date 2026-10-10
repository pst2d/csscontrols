program csscontrols_demo;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  Interfaces, Forms, csstailwind, demomain;


begin
  CSSTailwindEnable;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TDemoForm, DemoForm);   // main form: closing it terminates application
  Application.Run;
end.
