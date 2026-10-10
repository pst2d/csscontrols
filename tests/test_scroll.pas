unit test_scroll;

(*
  Scrolling (overflow auto), scrollbars, z-index, focus and ring
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, GraphType, IntfGraphics, FPImage, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestScroll }

  TTestScroll = class(TTestCase)
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
    procedure TestScrollRange;
    procedure TestScrollClamp;
    procedure TestScrollPaint;
    procedure TestScrollHitTest;
    procedure TestHorizontalScroll;
    procedure TestOverflowEnd;
    procedure TestOverflowEndIsClipped;
    procedure TestScrollbar;
    procedure TestNoScrollWhenContentFits;
    procedure TestClipRectOfScrolledNode;
    procedure TestZIndex;
    procedure TestFocusWithinRing;
  end;

implementation

procedure TTestScroll.Render(AWidth, AHeight: Integer);
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

procedure TTestScroll.CheckPixel(const AMsg: String; X, Y: Integer; AExpected: TColor);
var
  C, E: TFPColor;
begin
  C := FImage.Colors[X, Y];
  E := TColorToFPColor(AExpected);
  if (Abs(C.Red shr 8 - E.Red shr 8) > 40) or (Abs(C.Green shr 8 - E.Green shr 8) > 40) or (Abs(C.Blue shr 8 - E.Blue shr 8) > 40) then
    Fail(Format('%s: pixel [%d,%d] expected %.6x but was %.2x%.2x%.2x', [AMsg, X, Y, AExpected, C.Blue shr 8, C.Green shr 8, C.Red shr 8]));
end;

procedure TTestScroll.NodeClick(Sender: TObject);
begin
end;

procedure TTestScroll.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestScroll.TearDown;
begin
  FImage.Free;
  FRoot.Free;
end;

function AddBox(AParent: THtmlNode; const AStyle: String): THtmlNode;
begin
  Result := HTMLDiv(AStyle).AppendTo(AParent);
end;

procedure TTestScroll.TestScrollRange;
var
  S: THtmlNode;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto');
  AddBox(S, 'height: 120px');
  AddBox(S, 'height: 180px');
  Render(200, 150);
  AssertEquals('min', 0, S.ScrollMin.Y);
  AssertEquals('max', 200, S.ScrollMax.Y);
  AssertTrue(S.CanScroll(0, 10));
  AssertFalse(S.CanScroll(0, -10));
end;

procedure TTestScroll.TestScrollClamp;
var
  S: THtmlNode;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto; padding: 10px');
  AddBox(S, 'height: 300px');
  Render(200, 150);
  AssertEquals('padding is part of scrolled content', 200, S.ScrollMax.Y);   // 300 + 2 * 10 padding - 120 padding box
  S.ScrollBy(0, 1000);
  AssertEquals(200, S.ScrollY);
  S.ScrollBy(0, -5000);
  AssertEquals(0, S.ScrollY);
end;

procedure TTestScroll.TestScrollPaint;
var
  S: THtmlNode;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto');
  AddBox(S, 'height: 120px; background-color: red');
  AddBox(S, 'height: 180px; background-color: blue');
  Render(200, 150);
  CheckPixel('first child', 50, 50, clRed);
  CheckPixel('clipped', 50, 125, clWhite);
  S.SetScroll(0, 100);
  Render(200, 150);     // layout keeps scroll position
  AssertEquals(100, S.ScrollY);
  CheckPixel('scrolled first child', 50, 10, clRed);
  CheckPixel('scrolled second child', 50, 50, clBlue);
  CheckPixel('still clipped', 50, 125, clWhite);
end;

procedure TTestScroll.TestScrollHitTest;
var
  S, A, B: THtmlNode;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto');
  A := AddBox(S, 'height: 120px');
  B := AddBox(S, 'height: 180px');
  B.OnClick := @NodeClick;
  Render(200, 150);
  AssertFalse('outside of viewport', B.HitTest(Point(50, 130)));
  AssertNull(FRoot.NodeAtPosition(Point(50, 130)));
  S.SetScroll(0, 100);
  AssertTrue('scrolled into viewport', B.HitTest(Point(50, 50)));
  AssertTrue(FRoot.NodeAtPosition(Point(50, 50)) = B);
  AssertFalse('scrolled out', A.HitTest(Point(50, 50)));
end;

procedure TTestScroll.TestHorizontalScroll;
var
  S, A: THtmlNode;
begin
  S := AddBox(FRoot, 'width: 100px; height: 50px; overflow-x: auto; display: flex');
  AddBox(S, 'width: 80px; flex-shrink: 0; background-color: red');
  A := AddBox(S, 'width: 80px; flex-shrink: 0; background-color: blue');
  Render(200, 100);
  AssertEquals(60, S.ScrollMax.X);
  S.SetScroll(60, 0);
  Render(200, 100);
  CheckPixel('scrolled', 50, 25, clBlue);
  AssertTrue(A.HitTest(Point(50, 25)));
end;

procedure TTestScroll.TestOverflowEnd;
var
  S: THtmlNode;
begin
  // chat like list: content overflows top, scroll position 0 shows last items
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto; display: flex; flex-direction: column; justify-content: flex-end');
  AddBox(S, 'height: 80px; flex-shrink: 0; background-color: red');
  AddBox(S, 'height: 80px; flex-shrink: 0; background-color: blue');
  Render(200, 150);
  AssertEquals('can scroll up', -60, S.ScrollMin.Y);
  AssertEquals(0, S.ScrollMax.Y);
  CheckPixel('last item visible', 50, 90, clBlue);
  S.SetScroll(0, -60);
  Render(200, 150);
  CheckPixel('first item after scroll up', 50, 30, clRed);
end;

procedure TTestScroll.TestOverflowEndIsClipped;
var
  S: THtmlNode;
begin
  AddBox(FRoot, 'height: 50px');
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto; display: flex; flex-direction: column; justify-content: flex-end');
  AddBox(S, 'height: 80px; flex-shrink: 0; background-color: red');
  AddBox(S, 'height: 80px; flex-shrink: 0; background-color: blue');
  Render(200, 160);
  CheckPixel('content above scroll container is clipped', 50, 25, clWhite);
  CheckPixel('visible part', 50, 60, clRed);
  // rounded nodes with shadow and text
  S.Clear;
  HTMLDiv('height: 80px; flex-shrink: 0; background-color: red; border-radius: 10px; box-shadow: 0 2px 4px black').AppendTo(S).Text := 'Hello';
  HTMLDiv('height: 80px; flex-shrink: 0; background-color: blue; border-radius: 10px').AppendTo(S);
  Render(200, 160);
  CheckPixel('rounded content above is clipped', 50, 25, clWhite);
  CheckPixel('rounded corner area above is clipped', 3, 45, clWhite);
  // text of node which is whole outside of visible area
  S.Clear;
  HTMLDiv('height: 30px; flex-shrink: 0; color: black; font-size: 20px').AppendTo(S).Text := 'WWWWWWWW';
  HTMLDiv('height: 130px; flex-shrink: 0').AppendTo(S);
  Render(200, 160);
  CheckPixel('text outside is not painted', 20, 25, clWhite);
  CheckPixel('text outside is not painted', 40, 30, clWhite);
end;

procedure TTestScroll.TestScrollbar;
var
  S: THtmlNode;
  C: TFPColor;
begin
  S := AddBox(FRoot, 'width: 100px; height: 100px; overflow-y: auto');
  AddBox(S, 'height: 400px');
  Render(200, 150);
  C := FImage.Colors[95, 10];      // thumb at right side, top
  AssertTrue('thumb is painted', C.Red shr 8 < 220);
  C := FImage.Colors[95, 90];      // thumb is short (viewport / content)
  AssertTrue('track is transparent', C.Red shr 8 > 240);
  AssertTrue('thumb hit', S.ThumbAt(Point(95, 10)) = 1);
  S.ScrollByThumb(1, 0, 20);
  AssertTrue('drag thumb scrolls', S.ScrollY > 50);
end;

procedure TTestScroll.TestNoScrollWhenContentFits;
var
  S: THtmlNode;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto');
  AddBox(S, 'height: 50px');
  Render(200, 150);
  AssertEquals(0, S.ScrollMax.Y);
  AssertFalse(S.CanScroll(0, 10));
end;

procedure TTestScroll.TestClipRectOfScrolledNode;
var
  S, B: THtmlNode;
  R, Clip: TRect;
begin
  S := AddBox(FRoot, 'height: 100px; overflow-y: auto');
  AddBox(S, 'height: 120px');
  B := AddBox(S, 'height: 30px');
  Render(200, 150);
  Clip := B.ScreenClipRect;
  R := B.TransformedBounds(B.CompSize.ContentRect);
  AssertFalse('node is outside of visible area', (R.Top >= Clip.Top) and (R.Bottom <= Clip.Bottom));
  S.SetScroll(0, 60);
  R := B.TransformedBounds(B.CompSize.ContentRect);
  AssertTrue('scrolled node is visible', (R.Top >= Clip.Top) and (R.Bottom <= Clip.Bottom));
end;

procedure TTestScroll.TestZIndex;
var
  A, B: THtmlNode;
begin
  FRoot.InlineStyle := 'position: relative';
  A := AddBox(FRoot, 'position: absolute; left: 0; top: 0; width: 50px; height: 50px; background-color: red; z-index: 10');
  B := AddBox(FRoot, 'position: absolute; left: 20px; top: 20px; width: 50px; height: 50px; background-color: blue');
  A.OnClick := @NodeClick;
  B.OnClick := @NodeClick;
  Render(100, 100);
  CheckPixel('higher z-index is on top', 30, 30, clRed);
  AssertTrue('click goes to top node', FRoot.NodeAtPosition(Point(30, 30)) = A);
end;

procedure TTestScroll.TestFocusWithinRing;
var
  W, E: THtmlNode;
begin
  CSSTailwindEnable;
  try
    FRoot.InlineStyle := 'padding: 10px';
    W := HTMLNode('h-10 rounded-lg border border-slate-300 bg-white focus-within:ring-4 focus-within:ring-red-500').AppendTo(FRoot);
    E := HTMLNode('h-6').AppendTo(W);
    Render(200, 70);
    CheckPixel('no ring', 30, 8, clWhite);
    E.Focused := True;
    Render(200, 70);
    CheckPixel('ring around focused input', 30, 8, RGBToColor($ef, $44, $44));
  finally
    CSSTailwindDisable;
  end;
end;

initialization
  RegisterTest(TTestScroll);
end.
