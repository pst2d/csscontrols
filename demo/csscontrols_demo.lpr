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
  DemoForm := TDemoForm.CreateNew(Application);
  DemoForm.Show;
  Application.Run;
end.
