unit test_transform;

(*
  Transforms (translate, scale, rotate), hit test and dashed/dotted borders
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Graphics, GraphType, IntfGraphics, FPImage, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestTransform }

  TTestTransform = class(TTestCase)
  private
    FRoot: THtmlNode;
    FImage: TLazIntfImage;
    procedure Render(AWidth, AHeight: Integer);
    procedure CheckPixel(const AMsg: String; X, Y: Integer; AExpected: TColor);
    procedure NodeClick(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestTranslate;
    procedure TestTranslatePercent;
    procedure TestTranslateHitTest;
    procedure TestScale;
    procedure TestScaleOrigin;
    procedure TestRotate;
    procedure TestRotateHitTest;
    procedure TestTransformDoesNotChangeLayout;
    procedure TestIndividualProperties;
    procedure TestNestedTranslate;
    procedure TestNodeAtPositionTopmost;
    procedure TestTailwindTransforms;
    procedure TestTailwindHoverScale;
    procedure TestDashedBorder;
    procedure TestDottedBorder;
    procedure TestDashedRoundedCorner;
    procedure TestMixedBorderStyles;
    procedure TestTransformedTextSharp;
  end;

implementation

procedure TTestTransform.Render(AWidth, AHeight: Integer);
var
  Bmp: TBitmap;
begin
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, AWidth, AHeight);
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(AWidth, AHeight);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, AWidth, AHeight);
    FRoot.PaintTo(Bmp.Canvas);
    FreeAndNil(FImage);
    FImage := Bmp.CreateIntfImage;
  finally
    Bmp.Free;
  end;
end;

procedure TTestTransform.CheckPixel(const AMsg: String; X, Y: Integer; AExpected: TColor);
var
  C, E: TFPColor;
begin
  C := FImage.Colors[X, Y];
  E := TColorToFPColor(AExpected);
  if (Abs(C.Red shr 8 - E.Red shr 8) > 40) or (Abs(C.Green shr 8 - E.Green shr 8) > 40) or (Abs(C.Blue shr 8 - E.Blue shr 8) > 40) then
    Fail(Format('%s: pixel [%d,%d] expected %.6x but was %.2x%.2x%.2x', [AMsg, X, Y, AExpected, C.Blue shr 8, C.Green shr 8, C.Red shr 8]));
end;

procedure TTestTransform.NodeClick(Sender: TObject);
begin
end;

procedure TTestTransform.SetUp;
begin
  FRoot := THtmlNode.Create('padding: 20px');
end;

procedure TTestTransform.TearDown;
begin
  FImage.Free;
  FRoot.Free;
end;

procedure TTestTransform.TestTranslate;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; background-color: blue; transform: translate(30px, 10px)').AppendTo(FRoot);
  Render(100, 80);
  AssertTrue(A.TransformKind = tkTranslate);
  CheckPixel('original position is empty', 25, 25, clWhite);
  CheckPixel('translated', 55, 35, clBlue);
end;

procedure TTestTransform.TestTranslatePercent;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; background-color: blue; transform: translateX(100%)').AppendTo(FRoot);
  Render(100, 80);
  CheckPixel('moved by own width', 45, 25, clBlue);
  CheckPixel('original', 25, 25, clWhite);
  AssertNotNull(A);
end;

procedure TTestTransform.TestTranslateHitTest;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; transform: translate(30px, 10px)').AppendTo(FRoot);
  Render(100, 80);
  AssertTrue('hit at translated position', A.HitTest(Point(55, 35)));
  AssertFalse('no hit at original position', A.HitTest(Point(25, 25)));
end;

procedure TTestTransform.TestScale;
var
  A: THtmlNode;
begin
  // 20x20 box at (20,20) scaled 2x from center (30,30) -> (10,10)-(50,50)
  A := HTMLDiv('width: 20px; height: 20px; background-color: blue; transform: scale(2)').AppendTo(FRoot);
  Render(100, 80);
  AssertTrue(A.TransformKind = tkGeneral);
  CheckPixel('scaled outside original', 13, 13, clBlue);
  CheckPixel('scaled edge', 47, 47, clBlue);
  CheckPixel('outside scaled', 53, 53, clWhite);
  AssertTrue('hit test scaled', A.HitTest(Point(12, 12)));
  AssertFalse('hit test outside', A.HitTest(Point(52, 30)));
end;

procedure TTestTransform.TestScaleOrigin;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; background-color: blue; transform: scale(2); transform-origin: top left').AppendTo(FRoot);
  Render(100, 80);
  CheckPixel('top left stays', 21, 21, clBlue);
  CheckPixel('grows to bottom right', 57, 57, clBlue);
  CheckPixel('nothing before origin', 17, 17, clWhite);
  AssertNotNull(A);
end;

procedure TTestTransform.TestRotate;
var
  A: THtmlNode;
begin
  // 40x10 bar rotated 90 degrees around its center (40,25) -> vertical bar 10x40
  A := HTMLDiv('width: 40px; height: 10px; background-color: blue; transform: rotate(90deg)').AppendTo(FRoot);
  Render(100, 80);
  CheckPixel('rotated top', 40, 9, clBlue);
  CheckPixel('rotated bottom', 40, 41, clBlue);
  CheckPixel('original left end is empty', 23, 25, clWhite);
  AssertNotNull(A);
end;

procedure TTestTransform.TestRotateHitTest;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 40px; height: 10px; transform: rotate(90deg)').AppendTo(FRoot);
  Render(100, 80);
  AssertTrue('hit in rotated', A.HitTest(Point(40, 10)));
  AssertFalse('no hit in original', A.HitTest(Point(23, 25)));
end;

procedure TTestTransform.TestTransformDoesNotChangeLayout;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('height: 20px; transform: translateY(50px) scale(0.5)').AppendTo(FRoot);
  B := HTMLDiv('height: 20px').AppendTo(FRoot);
  Render(100, 100);
  AssertEquals('next node is not moved', 40, B.CompSize.ContentRect.Top);
  AssertEquals('layout box of transformed node', 20, A.CompSize.ContentRect.Top);
end;

procedure TTestTransform.TestIndividualProperties;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; translate: 30px 0').AppendTo(FRoot);
  Render(100, 80);
  AssertTrue(A.HitTest(Point(55, 25)));
  A.InlineStyle := 'width: 20px; height: 20px; rotate: 45deg';
  Render(100, 80);
  AssertTrue(A.TransformKind = tkGeneral);
  A.InlineStyle := 'width: 20px; height: 20px; scale: 1';
  Render(100, 80);
  AssertTrue(A.TransformKind = tkNone);
end;

procedure TTestTransform.TestNestedTranslate;
var
  P, C: THtmlNode;
begin
  P := HTMLDiv('width: 40px; height: 40px; transform: translateX(20px)').AppendTo(FRoot);
  C := HTMLDiv('width: 10px; height: 10px; background-color: red; transform: translateY(10px)').AppendTo(P);
  Render(100, 80);
  CheckPixel('both translations', 45, 35, clRed);
  AssertTrue(C.HitTest(Point(45, 35)));
  AssertFalse(C.HitTest(Point(25, 25)));
end;

procedure TTestTransform.TestNodeAtPositionTopmost;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('height: 20px').AppendTo(FRoot);
  B := HTMLDiv('height: 20px; transform: translateY(-20px)').AppendTo(FRoot);   // over A
  A.OnClick := @NodeClick;
  B.OnClick := @NodeClick;
  Render(100, 80);
  AssertTrue('translated node is on top', FRoot.NodeAtPosition(Point(30, 25)) = B);
end;

procedure TTestTransform.TestTailwindTransforms;
var
  A: THtmlNode;
  D: String;
  O: Integer;
begin
  AssertTrue(TailwindResolve('rotate-45', D, O));
  AssertTrue(Pos('--tw-rotate:45deg', D) = 1);
  AssertTrue(TailwindResolve('-translate-x-1/2', D, O));
  AssertTrue(Pos('--tw-translate-x:-50%', D) = 1);
  AssertTrue(TailwindResolve('scale-105', D, O));
  AssertTrue(Pos('--tw-scale-x:1.05;--tw-scale-y:1.05', D) = 1);
  CSSTailwindEnable;
  try
    // absolute centering: left-1/2 -translate-x-1/2
    FRoot.SetClass('relative w-[100px] h-[60px] p-0');
    A := HTMLNode('absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-5 h-5 bg-blue-500').AppendTo(FRoot);
    Render(100, 60);
    CheckPixel('centered', 50, 30, RGBToColor($3b, $82, $f6));
    CheckPixel('not at left-1/2 position', 68, 48, clWhite);
    AssertTrue(A.HitTest(Point(45, 25)));
  finally
    CSSTailwindDisable;
  end;
end;

procedure TTestTransform.TestTailwindHoverScale;
var
  A: THtmlNode;
begin
  CSSTailwindEnable;
  try
    A := HTMLNode('w-5 h-5 bg-blue-500 hover:scale-150').AppendTo(FRoot);
    Render(100, 80);
    AssertTrue(A.TransformKind = tkNone);
    A.Hovered := True;
    Render(100, 80);
    AssertTrue(A.TransformKind = tkGeneral);
    CheckPixel('scaled on hover', 17, 17, RGBToColor($3b, $82, $f6));
  finally
    CSSTailwindDisable;
  end;
end;

procedure TTestTransform.TestDashedBorder;
var
  A: THtmlNode;
begin
  // top side length 100, dash 6, gap 6: dash at x 20..26, gap 26..32 (approximately)
  A := HTMLDiv('width: 100px; height: 40px; border: 2px dashed red').AppendTo(FRoot);
  Render(140, 80);
  CheckPixel('first dash', 23, 21, clRed);
  CheckPixel('first gap', 30, 21, clWhite);
  CheckPixel('second dash', 36, 21, clRed);
  CheckPixel('corner is solid', 21, 21, clRed);
  CheckPixel('inside', 70, 40, clWhite);
  AssertNotNull(A);
end;

procedure TTestTransform.TestDottedBorder;
var
  A: THtmlNode;
  C: TFPColor;
  Dots, Gaps, X: Integer;
begin
  A := HTMLDiv('width: 100px; height: 40px; border: 4px dotted red').AppendTo(FRoot);
  Render(140, 80);
  // count transitions along top border middle line
  Dots := 0;
  Gaps := 0;
  for X := 30 to 110 do begin
    C := FImage.Colors[X, 22];
    if C.Green shr 8 < 100 then Inc(Dots) else Inc(Gaps);
  end;
  AssertTrue('dots are painted', Dots > 20);
  AssertTrue('gaps between dots', Gaps > 20);
  AssertNotNull(A);
end;

procedure TTestTransform.TestDashedRoundedCorner;
var
  A: THtmlNode;
begin
  // dashes follow rounded corner, join of top and left side (middle of corner arc) is painted
  A := HTMLDiv('width: 100px; height: 60px; border: 4px dashed red; border-radius: 20px').AppendTo(FRoot);
  Render(140, 100);
  CheckPixel('middle of corner arc', 20 + 7, 20 + 7, clRed);
  CheckPixel('outside corner', 21, 21, clWhite);
  CheckPixel('inside', 70, 50, clWhite);
  AssertNotNull(A);
end;

procedure TTestTransform.TestMixedBorderStyles;
var
  A: THtmlNode;
  X, Dash, Gap: Integer;
  C: TFPColor;
begin
  A := HTMLDiv('width: 100px; height: 60px; border-top: 3px dashed blue; border-left: 6px solid red; border-radius: 10px').AppendTo(FRoot);
  Render(140, 100);
  CheckPixel('solid left side', 22, 50, clRed);
  Dash := 0;
  Gap := 0;
  for X := 40 to 110 do begin      // middle line of top border
    C := FImage.Colors[X, 21];
    if (C.Blue shr 8 > 200) and (C.Red shr 8 < 60) then Inc(Dash);
    if (C.Blue shr 8 > 200) and (C.Red shr 8 > 200) then Inc(Gap);
  end;
  AssertTrue('top has dashes', Dash > 10);
  AssertTrue('top has gaps', Gap > 10);
  AssertNotNull(A);
end;

procedure TTestTransform.TestTransformedTextSharp;
var
  A: THtmlNode;
  X, Y, Darkest: Integer;
  C: TFPColor;
begin
  // scaled text is rendered in target resolution: text keeps its color (not blurred to lighter color)
  A := HTMLDiv('width: 60px; height: 20px; color: black; transform: scale(2); font-size: 12px').AppendTo(FRoot);
  A.Text := 'Hello';
  Render(160, 100);
  Darkest := 255;
  for Y := 0 to 99 do
    for X := 0 to 159 do begin
      C := FImage.Colors[X, Y];
      Darkest := Min(Darkest, C.Red shr 8);
    end;
  AssertTrue('scaled text is dark', Darkest < 40);
end;

initialization
  RegisterTest(TTestTransform);
end.
