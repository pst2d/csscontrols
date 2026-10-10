(*
  Render demo scenes to PNG files (visual check without GUI)
  Usage: renderdemo [output directory] [width]
*)
program renderdemo;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, SysUtils, Graphics, cssbase, csstailwind, demoscenes;

procedure RenderScene(const AScene: TDemoScene; const ADir: String; AWidth: Integer);
var
  Body: THtmlNode;
  Sheet: TCSSStyleSheet;
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
  H: Integer;
begin
  Sheet := TCSSStyleSheet.Create(nil);
  Body := THtmlNode.Create;
  Bmp := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    Body.StyleSheet := Sheet;
    Body.ViewportWidth := AWidth;
    AScene.Build(Body, Sheet);
    Body.ApplyStyles;
    Body.LayoutTo(0, 0, AWidth, -1);
    H := Body.CompSize.MarginRect.Bottom;
    if H < 10 then H := 10;
    Bmp.SetSize(AWidth, H);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, AWidth, H);
    Body.PaintTo(Bmp.Canvas);
    Png.Assign(Bmp);
    Png.SaveToFile(IncludeTrailingPathDelimiter(ADir) + LowerCase(AScene.Name) + '-' + IntToStr(AWidth) + '.png');
    WriteLn(AScene.Name, ': ', AWidth, 'x', H);
  finally
    Png.Free;
    Bmp.Free;
    Body.Free;
    Sheet.Free;
  end;
end;

var
  Dir: String;
  W, I: Integer;
begin
  Application.Initialize;
  CSSTailwindEnable;
  Dir := 'out';
  W := 720;
  if ParamCount >= 1 then Dir := ParamStr(1);
  if ParamCount >= 2 then W := StrToIntDef(ParamStr(2), W);
  ForceDirectories(Dir);
  for I := 0 to High(DEMO_SCENES) do
    RenderScene(DEMO_SCENES[I], Dir, W);
end.
