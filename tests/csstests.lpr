program csstests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, consoletestrunner, csstailwind,
  test_parser, test_tree, test_cascade, test_layout, test_tailwind, test_render, test_transform, test_html, test_scroll, test_grid, test_anim, test_utilities, test_shape;

var
  App: TTestRunner;
begin
  Application.Initialize;
  CSSTailwindDisable;   // tests start from plain CSS (csscomponents enables Tailwind in initialization)
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Title := 'csscontrols tests';
  App.Run;
  App.Free;
end.
