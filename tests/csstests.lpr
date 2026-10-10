program csstests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, consoletestrunner,
  test_parser, test_tree, test_cascade, test_layout, test_tailwind, test_render, test_transform, test_html;

var
  App: TTestRunner;
begin
  Application.Initialize;
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Title := 'csscontrols tests';
  App.Run;
  App.Free;
end.
