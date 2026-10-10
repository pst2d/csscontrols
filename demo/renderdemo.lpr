(*
  Render demo scenes to PNG files (visual check without GUI)
  Usage: renderdemo [output directory] [width] [scene name] [zoom]
         renderdemo bench [width]
*)
program renderdemo;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, SysUtils, Graphics, IntfGraphics, cssbase, csstailwind, demoscenes;

(*
  Zoom bitmap with nearest neighbor (to see antialiasing)
*)
procedure ZoomBitmap(ABitmap: TBitmap; AZoom: Integer);
var
  Src, Dst: TLazIntfImage;
  X, Y: Integer;
begin
  Src := ABitmap.CreateIntfImage;
  Dst := TLazIntfImage.Create(0, 0);
  try
    Dst.DataDescription := Src.DataDescription;
    Dst.SetSize(Src.Width * AZoom, Src.Height * AZoom);
    for Y := 0 to Dst.Height - 1 do
      for X := 0 to Dst.Width - 1 do
        Dst.Colors[X, Y] := Src.Colors[X div AZoom, Y div AZoom];
    ABitmap.LoadFromIntfImage(Dst);
  finally
    Src.Free;
    Dst.Free;
  end;
end;

(*
  Measure layout and paint time of scene
*)
procedure BenchScene(const AScene: TDemoScene; AWidth: Integer);
const
  COUNT = 100;
var
  Body: THtmlNode;
  Sheet: TCSSStyleSheet;
  Bmp: TBitmap;
  I: Integer;
  T0, TFirst, TLayout, TPaint: QWord;
begin
  Sheet := TCSSStyleSheet.Create(nil);
  Body := THtmlNode.Create;
  Bmp := TBitmap.Create;
  try
    Body.StyleSheet := Sheet;
    Body.ViewportWidth := AWidth;
    AScene.Build(Body, Sheet);
    Body.ApplyStyles;
    Body.LayoutTo(0, 0, AWidth, -1);
    Bmp.SetSize(AWidth, Body.CompSize.MarginRect.Bottom);
    CSSClearPaintCache;
    T0 := GetTickCount64;
    Body.PaintTo(Bmp.Canvas);         // first paint (caches are empty)
    TFirst := GetTickCount64 - T0;
    T0 := GetTickCount64;
    for I := 1 to COUNT do begin
      Body.ApplyStyles;
      Body.LayoutTo(0, 0, AWidth, -1);
    end;
    TLayout := GetTickCount64 - T0;
    T0 := GetTickCount64;
    for I := 1 to COUNT do Body.PaintTo(Bmp.Canvas);
    TPaint := GetTickCount64 - T0;
    WriteLn(Format('%-12s first paint %4d ms, styles+layout %6.2f ms, paint %6.2f ms', [AScene.Name, TFirst, TLayout / COUNT, TPaint / COUNT]));
  finally
    Bmp.Free;
    Body.Free;
    Sheet.Free;
  end;
end;

procedure RenderScene(const AScene: TDemoScene; const ADir: String; AWidth: Integer; AZoom: Integer);
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
    if AZoom > 1 then ZoomBitmap(Bmp, AZoom);
    Png.Assign(Bmp);
    if AZoom > 1 then
      Png.SaveToFile(IncludeTrailingPathDelimiter(ADir) + LowerCase(AScene.Name) + '-' + IntToStr(AWidth) + '-x' + IntToStr(AZoom) + '.png')
    else
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
  Dir, Scene: String;
  W, I, Zoom: Integer;
begin
  Application.Initialize;
  CSSTailwindEnable;
  Dir := 'out';
  W := 720;
  if ParamCount >= 1 then Dir := ParamStr(1);
  if ParamCount >= 2 then W := StrToIntDef(ParamStr(2), W);
  Scene := '';
  if ParamCount >= 3 then Scene := ParamStr(3);
  Zoom := 1;
  if ParamCount >= 4 then Zoom := StrToIntDef(ParamStr(4), 1);
  if Dir = 'bench' then begin
    for I := 0 to High(DEMO_SCENES) do BenchScene(DEMO_SCENES[I], W);
    Exit;
  end;
  ForceDirectories(Dir);
  for I := 0 to High(DEMO_SCENES) do
    if (Scene = '') or SameText(Scene, DEMO_SCENES[I].Name) then
      RenderScene(DEMO_SCENES[I], Dir, W, Zoom);
end.
