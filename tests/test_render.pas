unit test_render;

(*
  Pixel tests of background and border painting (border-radius, different border widths and colors)
  Pixels are sampled at least ~1.5px from edges, so tests work with and without antialiasing.
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, GraphType, IntfGraphics, FPImage, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestRender }

  TTestRender = class(TTestCase)
  private
    FRoot: THtmlNode;
    FImage: TLazIntfImage;
    procedure Render(const AStyle: String; AWidth, AHeight: Integer);
    procedure CheckPixel(const AMsg: String; X, Y: Integer; AExpected: TColor);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSolidBackground;
    procedure TestRadiusOutsideIsTransparent;
    procedure TestTopBorderOnlyWithRadius;
    procedure TestDifferentBorderWidthsJoin;
    procedure TestSquareCornerJoin;
    procedure TestInnerRadius;
    procedure TestRadiusSmallerThanBorder;
    procedure TestEllipticalCorner;
    procedure TestPillShape;
    procedure TestOverlappingRadiiAreReduced;
    procedure TestDifferentRadiusPerCorner;
    procedure TestBorderWithoutStyleIsNotPainted;
    procedure TestTransparentBorderShowsBackground;
    procedure TestPercentRadius;
    procedure TestAntialiasing;
    procedure TestLinearGradient;
    procedure TestGradientCorner;
    procedure TestAlphaBackground;
    procedure TestBackgroundImage;
    procedure TestBackgroundImageNoRepeat;
    procedure TestCustomPropertyInGradient;
    procedure TestAlphaBorderAndText;
    procedure TestTailwindGradient;
  end;

  { TTestRenderRetina - same tests with bitmaps rendered in 2x resolution }

  TTestRenderRetina = class(TTestRender)
  protected
    procedure SetUp; override;
  end;

implementation

const
  BG = clBlue;
  OUTSIDE = clWhite;

procedure TTestRender.Render(const AStyle: String; AWidth, AHeight: Integer);
var
  Bmp: TBitmap;
begin
  FRoot.InlineStyle := AStyle;
  FRoot.LayoutTo(0, 0, AWidth, AHeight);
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(AWidth, AHeight);
    Bmp.Canvas.Brush.Color := OUTSIDE;
    Bmp.Canvas.FillRect(0, 0, AWidth, AHeight);
    FRoot.PaintTo(Bmp.Canvas);
    FreeAndNil(FImage);
    FImage := Bmp.CreateIntfImage;
  finally
    Bmp.Free;
  end;
end;

procedure TTestRender.CheckPixel(const AMsg: String; X, Y: Integer; AExpected: TColor);
var
  C: TFPColor;
  E: TFPColor;
begin
  C := FImage.Colors[X, Y];
  E := TColorToFPColor(AExpected);
  if (Abs(C.Red shr 8 - E.Red shr 8) > 40) or (Abs(C.Green shr 8 - E.Green shr 8) > 40) or (Abs(C.Blue shr 8 - E.Blue shr 8) > 40) then
    Fail(Format('%s: pixel [%d,%d] expected %.6x but was %.2x%.2x%.2x', [AMsg, X, Y, AExpected, C.Blue shr 8, C.Green shr 8, C.Red shr 8]));
end;

procedure TTestRender.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestRender.TearDown;
begin
  FImage.Free;
  FRoot.Free;
end;

procedure TTestRender.TestSolidBackground;
begin
  Render('background-color: blue', 50, 30);
  CheckPixel('top left', 0, 0, BG);
  CheckPixel('bottom right', 49, 29, BG);
end;

procedure TTestRender.TestRadiusOutsideIsTransparent;
begin
  Render('background-color: blue; border-radius: 20px', 100, 60);
  CheckPixel('outside top left', 2, 2, OUTSIDE);
  CheckPixel('outside top right', 97, 2, OUTSIDE);
  CheckPixel('outside bottom right', 97, 57, OUTSIDE);
  CheckPixel('outside bottom left', 2, 57, OUTSIDE);
  CheckPixel('inside', 50, 30, BG);
  CheckPixel('top edge middle', 50, 1, BG);
  CheckPixel('left edge middle', 1, 30, BG);
  CheckPixel('inside corner arc', 8, 8, BG);    // (12,12) from circle center, distance 17 < 20
end;

procedure TTestRender.TestTopBorderOnlyWithRadius;
begin
  // left border is 0, so whole top-left corner belongs to top border
  Render('background-color: blue; border-top: 10px solid red; border-radius: 20px', 100, 60);
  CheckPixel('outside', 2, 2, OUTSIDE);
  CheckPixel('top border', 50, 5, clRed);
  CheckPixel('background', 50, 30, BG);
  CheckPixel('left edge is background', 1, 35, BG);
  CheckPixel('top border in corner', 4, 12, clRed);       // between outer circle and inner ellipse (20x10)
  CheckPixel('background under corner', 14, 17, BG);      // inside inner ellipse
  CheckPixel('top border in right corner', 95, 12, clRed);
end;

procedure TTestRender.TestDifferentBorderWidthsJoin;
begin
  // join line goes from outer corner (0,0) to inner corner (4,10)
  Render('background-color: blue; border-top: 10px solid red; border-left: 4px solid lime; border-radius: 20px', 100, 60);
  CheckPixel('top side of join', 10, 4, clRed);
  CheckPixel('left side of join', 2, 16, clLime);
  CheckPixel('left border', 2, 40, clLime);
  CheckPixel('top border', 60, 5, clRed);
  CheckPixel('background', 30, 30, BG);
end;

procedure TTestRender.TestSquareCornerJoin;
begin
  Render('background-color: blue; border-top: 10px solid red; border-right: 10px solid lime', 100, 60);
  CheckPixel('top', 96, 2, clRed);     // 4px from right, 2px from top
  CheckPixel('right', 98, 7, clLime);   // 2px from right, 7px from top
  CheckPixel('top far', 50, 5, clRed);
  CheckPixel('right far', 95, 40, clLime);
  CheckPixel('background', 50, 40, BG);
end;

procedure TTestRender.TestInnerRadius;
begin
  // inner radius = 15 - 10 = 5
  Render('background-color: blue; border: 10px solid black; border-radius: 15px', 100, 100);
  CheckPixel('outside', 1, 1, OUTSIDE);
  CheckPixel('border in corner', 10, 10, clBlack);    // distance from inner circle center (15,15) is 7 > 5
  CheckPixel('background inside inner radius', 14, 13, BG);
  CheckPixel('border middle', 5, 50, clBlack);
  CheckPixel('background', 50, 50, BG);
end;

procedure TTestRender.TestRadiusSmallerThanBorder;
begin
  // inner corner is square
  Render('background-color: blue; border: 10px solid black; border-radius: 5px', 100, 100);
  CheckPixel('outside', 0, 0, OUTSIDE);
  CheckPixel('border', 8, 8, clBlack);
  CheckPixel('background in inner corner', 12, 12, BG);
end;

procedure TTestRender.TestEllipticalCorner;
begin
  Render('background-color: blue; border-top-left-radius: 30px 10px', 100, 60);
  CheckPixel('outside ellipse', 8, 2, OUTSIDE);    // ((8-30)/30)^2 + ((2-10)/10)^2 > 1
  CheckPixel('inside ellipse', 20, 4, BG);
  CheckPixel('below corner', 1, 14, BG);
  CheckPixel('top right is square', 99, 0, BG);
end;

procedure TTestRender.TestPillShape;
begin
  // 9999px radius is reduced to half of height
  Render('background-color: blue; border-radius: 9999px', 100, 40);
  CheckPixel('outside', 3, 3, OUTSIDE);
  CheckPixel('top middle', 50, 1, BG);
  CheckPixel('left middle', 1, 20, BG);
  CheckPixel('outside right', 96, 3, OUTSIDE);
end;

procedure TTestRender.TestOverlappingRadiiAreReduced;
begin
  // top radii 80 + 80 > 100, all radii are scaled by 100/160 -> 50
  Render('background-color: blue; border-top-left-radius: 80px; border-top-right-radius: 80px', 100, 200);
  CheckPixel('inside reduced radius', 25, 10, BG);
  CheckPixel('outside', 5, 5, OUTSIDE);
  CheckPixel('top middle', 50, 2, BG);
end;

procedure TTestRender.TestDifferentRadiusPerCorner;
begin
  Render('background-color: blue; border-radius: 0 10px 30px 5px', 100, 100);
  CheckPixel('top left square', 0, 0, BG);
  CheckPixel('top right outside', 98, 1, OUTSIDE);
  CheckPixel('top right inside', 95, 4, BG);
  CheckPixel('bottom right outside', 94, 94, OUTSIDE);   // 30px radius
  CheckPixel('bottom right inside', 85, 85, BG);
  CheckPixel('bottom left outside', 0, 99, OUTSIDE);
  CheckPixel('bottom left inside', 3, 96, BG);
end;

procedure TTestRender.TestBorderWithoutStyleIsNotPainted;
begin
  Render('background-color: blue; border-width: 10px; border-color: red', 60, 60);
  CheckPixel('no border', 2, 30, BG);
end;

procedure TTestRender.TestTransparentBorderShowsBackground;
begin
  Render('background-color: blue; border: 10px solid transparent', 60, 60);
  CheckPixel('transparent border', 3, 30, BG);
end;

procedure TTestRender.TestPercentRadius;
begin
  Render('background-color: blue; border-radius: 50%', 100, 50);
  CheckPixel('outside', 4, 4, OUTSIDE);
  CheckPixel('left middle', 1, 25, BG);
  CheckPixel('center', 50, 25, BG);
  CheckPixel('outside near top right', 92, 4, OUTSIDE);
end;

procedure TTestRender.TestAntialiasing;
var
  C: TFPColor;
begin
  if FRoot.PaintScale <> 1 then Exit;   // 2x bitmap is downsampled to 1x test bitmap
  // circle edge crosses pixel [6,5] (about 77 % covered)
  Render('background-color: blue; border-radius: 20px', 100, 60);
  C := FImage.Colors[6, 5];
  AssertTrue('antialiased edge pixel is blended', (C.Red shr 8 > 20) and (C.Red shr 8 < 235));
  CSSAntialiasing := False;
  try
    Render('background-color: blue; border-radius: 20px; width: 100px', 100, 60);
    C := FImage.Colors[6, 5];
    AssertTrue('without antialiasing pixel is not blended', (C.Red shr 8 < 20) or (C.Red shr 8 > 235));
  finally
    CSSAntialiasing := True;
  end;
end;

procedure TTestRender.TestLinearGradient;
begin
  Render('background-image: linear-gradient(to right, red, blue)', 101, 20);
  CheckPixel('left', 0, 10, clRed);
  CheckPixel('middle', 50, 10, RGBToColor(127, 0, 128));
  CheckPixel('right', 100, 10, clBlue);
  Render('background-image: linear-gradient(red 0%, red 50%, lime 50%, lime 100%)', 20, 100);
  CheckPixel('top half', 10, 40, clRed);
  CheckPixel('bottom half', 10, 60, clLime);
end;

procedure TTestRender.TestGradientCorner;
begin
  Render('background-image: linear-gradient(to right, red, blue); border-radius: 20px', 100, 60);
  CheckPixel('outside corner', 2, 2, OUTSIDE);
  CheckPixel('inside', 3, 30, clRed);
end;

procedure TTestRender.TestAlphaBackground;
begin
  Render('background-color: rgba(0, 0, 255, 0.5)', 40, 40);
  CheckPixel('half transparent blue over white', 20, 20, RGBToColor(127, 127, 255));
  Render('background: #0000ff80; border-radius: 10px', 40, 40);
  CheckPixel('hex alpha', 20, 20, RGBToColor(127, 127, 255));
  CheckPixel('outside corner', 1, 1, OUTSIDE);
end;

function TestImage: TBitmap;     // 2x2: red green / blue black
begin
  Result := TBitmap.Create;
  Result.SetSize(2, 2);
  Result.Canvas.Pixels[0, 0] := clRed;
  Result.Canvas.Pixels[1, 0] := clLime;
  Result.Canvas.Pixels[0, 1] := clBlue;
  Result.Canvas.Pixels[1, 1] := clBlack;
end;

procedure TTestRender.TestBackgroundImage;
var
  Bmp: TBitmap;
begin
  Bmp := TestImage;
  try
    CSSRegisterImage('test.png', Bmp);
  finally
    Bmp.Free;
  end;
  Render('background-image: url("test.png"); background-size: cover', 40, 40);
  CheckPixel('top left', 3, 3, clRed);
  CheckPixel('top right', 36, 3, clLime);
  CheckPixel('bottom left', 3, 36, clBlue);
  CheckPixel('bottom right', 36, 36, clBlack);
end;

procedure TTestRender.TestBackgroundImageNoRepeat;
var
  Bmp: TBitmap;
begin
  Bmp := TestImage;
  try
    CSSRegisterImage('test.png', Bmp);
  finally
    Bmp.Free;
  end;
  Render('background: yellow url(test.png) no-repeat center / 20px 20px', 60, 60);
  CheckPixel('background color around image', 5, 5, clYellow);
  CheckPixel('image top left', 22, 22, clRed);
  CheckPixel('image bottom right', 37, 37, clBlack);
  Render('background-image: url(test.png); background-size: 20px', 60, 60);
  CheckPixel('repeated image', 42, 42, clRed);
end;

procedure TTestRender.TestCustomPropertyInGradient;
begin
  Render('--from: red; --to: blue; background-image: linear-gradient(to right, var(--from), var(--missing, var(--to)))', 101, 10);
  CheckPixel('left', 0, 5, clRed);
  CheckPixel('right', 100, 5, clBlue);
end;

procedure TTestRender.TestAlphaBorderAndText;
begin
  // border with alpha is blended with node background
  Render('background-color: black; border: 10px solid rgba(255, 255, 255, 0.5)', 60, 60);
  CheckPixel('half white border on black', 4, 30, RGBToColor(128, 128, 128));
  AssertEquals('text color with alpha', RGBToColor(128, 128, 128), ColorToRGB(FRoot.EffectiveColor(CSSToColor('rgba(255,255,255,0.5)'))));
end;

procedure TTestRender.TestTailwindGradient;
begin
  CSSTailwindEnable;
  try
    FRoot.SetClass('bg-gradient-to-r from-red-500 to-blue-500');
    Render('', 101, 10);
    CheckPixel('from', 0, 5, RGBToColor($ef, $44, $44));
    CheckPixel('to', 100, 5, RGBToColor($3b, $82, $f6));
    // from only: fades to transparent
    FRoot.SetClass('bg-gradient-to-r from-black');
    Render('', 101, 10);
    CheckPixel('from only start', 0, 5, clBlack);
    CheckPixel('from only end', 100, 5, OUTSIDE);
    // via
    FRoot.SetClass('bg-gradient-to-r from-red-500 via-lime-500 to-blue-500');
    Render('', 101, 10);
    CheckPixel('via', 50, 5, RGBToColor($84, $cc, $16));
    // opacity modifier
    FRoot.SetClass('bg-black/50');
    Render('', 20, 20);
    CheckPixel('bg-black/50', 10, 10, RGBToColor(128, 128, 128));
    FRoot.SetClass('');
  finally
    CSSTailwindDisable;
  end;
end;

{ TTestRenderRetina }

procedure TTestRenderRetina.SetUp;
begin
  inherited SetUp;
  FRoot.PaintScale := 2;     // bitmaps in 2x resolution (macOS Retina), drawn by StretchDraw
end;

initialization
  RegisterTest(TTestRender);
  RegisterTest(TTestRenderRetina);
end.
