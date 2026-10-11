unit test_utilities;

(*
  Dark mode, utilities for children (space, divide), line-clamp, aspect-ratio, sticky, inset shadow
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, IntfGraphics, FPImage, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestUtilities }

  TTestUtilities = class(TTestCase)
  private
    FRoot: THtmlNode;
    procedure Layout(AWidth: Integer; AHeight: Integer = -1);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDarkVariant;
    procedure TestSpaceX;
    procedure TestSpaceY;
    procedure TestDivideY;
    procedure TestLineClamp;
    procedure TestAspectRatio;
    procedure TestSticky;
    procedure TestInsetShadow;
  end;

implementation

procedure TTestUtilities.Layout(AWidth: Integer; AHeight: Integer);
begin
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, AWidth, AHeight);
end;

procedure TTestUtilities.SetUp;
begin
  CSSTailwindEnable;
  FRoot := THtmlNode.Create;
end;

procedure TTestUtilities.TearDown;
begin
  FRoot.Free;
  CSSDarkMode := False;
  CSSTailwindDisable;
end;

procedure TTestUtilities.TestDarkVariant;
var
  A: THtmlNode;
begin
  A := HTMLNode('bg-white dark:bg-slate-900').AppendTo(FRoot);
  Layout(100);
  AssertEquals('light', clWhite, ColorToRGB(A.CompStyle.Background.Color.Value));
  CSSDarkMode := True;
  Layout(100);
  AssertEquals('dark', RGBToColor($0F, $17, $2A), ColorToRGB(A.CompStyle.Background.Color.Value));
end;

procedure TTestUtilities.TestSpaceX;
var
  F, A, B, C: THtmlNode;
begin
  F := HTMLNode('flex space-x-4').AppendTo(FRoot);
  A := HTMLNode('w-10 h-4').AppendTo(F);
  B := HTMLNode('w-10 h-4').AppendTo(F);
  C := HTMLNode('w-10 h-4').AppendTo(F);
  Layout(300);
  AssertEquals('first without margin', 0, A.CompSize.ContentRect.Left);
  AssertEquals('second', 56, B.CompSize.ContentRect.Left);
  AssertEquals('third', 112, C.CompSize.ContentRect.Left);
end;

procedure TTestUtilities.TestSpaceY;
var
  F, A, B: THtmlNode;
begin
  F := HTMLNode('space-y-2').AppendTo(FRoot);
  A := HTMLNode('h-4').AppendTo(F);
  B := HTMLNode('h-4').AppendTo(F);
  Layout(300);
  AssertEquals('first', 0, A.CompSize.ContentRect.Top);
  AssertEquals('second', 24, B.CompSize.ContentRect.Top);
end;

procedure TTestUtilities.TestDivideY;
var
  F, A, B: THtmlNode;
begin
  F := HTMLNode('divide-y divide-slate-200').AppendTo(FRoot);
  A := HTMLNode('h-4').AppendTo(F);
  B := HTMLNode('h-4').AppendTo(F);
  Layout(300);
  AssertEquals('first has no border', 0, A.CompSize.Border.Top);
  AssertEquals('second has top border', 1, B.CompSize.Border.Top);
  AssertTrue('divide color', B.CompStyle.Border[csTop].Color.ColorType = cctNormal);
end;

procedure TTestUtilities.TestLineClamp;
var
  A, B: THtmlNode;
  S: String;
  I: Integer;
begin
  S := '';
  for I := 1 to 60 do S := S + 'word ';
  A := HTMLNode('w-40', S).AppendTo(FRoot);
  B := HTMLNode('w-40 line-clamp-2', S).AppendTo(FRoot);
  Layout(300);
  AssertTrue('clamped is lower', B.CompSize.ContentRect.Height < A.CompSize.ContentRect.Height div 3);
  AssertTrue('clamped is two lines', B.CompSize.ContentRect.Height > 20);
end;

procedure TTestUtilities.TestAspectRatio;
var
  A, B: THtmlNode;
begin
  A := HTMLNode('w-40 aspect-video').AppendTo(FRoot);
  B := HTMLNode('w-20 aspect-square').AppendTo(FRoot);
  Layout(300);
  AssertEquals('16 / 9', 90, A.CompSize.ContentRect.Height);
  AssertEquals('square', 80, B.CompSize.ContentRect.Height);
end;

procedure TTestUtilities.TestSticky;
var
  S, H, A: THtmlNode;
  P: TPointF;
begin
  S := HTMLNode('h-20 overflow-y-auto').AppendTo(FRoot);
  H := HTMLNode('sticky top-0 h-5').AppendTo(S);
  A := HTMLNode('h-96').AppendTo(S);
  Layout(200);
  S.SetScroll(0, 50);
  P := H.LayoutToScreen(PointF(H.CompSize.ContentRect.Left, H.CompSize.ContentRect.Top));
  AssertEquals('header stays at top', 0, Round(P.y));
  P := A.LayoutToScreen(PointF(A.CompSize.ContentRect.Left, A.CompSize.ContentRect.Top));
  AssertEquals('content is scrolled', 20 - 50, Round(P.y));
end;

procedure TTestUtilities.TestInsetShadow;
var
  Bmp: TBitmap;
  Img: TLazIntfImage;
  Top, Mid: TFPColor;
begin
  FRoot.InlineStyle := 'background-color: white; box-shadow: inset 0 6px 6px 0 rgba(0, 0, 0, 0.5); border-radius: 8px';
  FRoot.LayoutTo(0, 0, 200, 100);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(200, 100);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, 200, 100);
    FRoot.PaintTo(Bmp.Canvas);
    Img := Bmp.CreateIntfImage;
    try
      Top := Img.Colors[100, 2];
      Mid := Img.Colors[100, 50];
    finally
      Img.Free;
    end;
  finally
    Bmp.Free;
  end;
  AssertTrue('shadow at top inside', Top.Red shr 8 < 200);
  AssertTrue('no shadow in middle', Mid.Red shr 8 > 250);
end;

initialization
  RegisterTest(TTestUtilities);
end.
