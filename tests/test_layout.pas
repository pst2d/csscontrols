unit test_layout;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, cssbase;

type

  { TTestLayout }

  TTestLayout = class(TTestCase)
  private
    FRoot: THtmlNode;
    function Add(AParent: THtmlNode; const AStyle: String): THtmlNode;
    procedure Layout(AWidth: Integer; AHeight: Integer = -1);
    procedure CheckBox(const AMsg: String; ANode: THtmlNode; ALeft, ATop, AWidth, AHeight: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBlocksFillWidth;
    procedure TestBoxSizing;
    procedure TestBorderWithoutStyleHasNoWidth;
    procedure TestMarginAutoCenters;
    procedure TestMaxWidthWithMarginAuto;
    procedure TestMinWidth;
    procedure TestEmRemUnits;
    procedure TestPixelRatio;
    procedure TestAbsoluteRightBottom;
    procedure TestRelativeOffset;
    procedure TestFloatRight;
    procedure TestFlexRow;
    procedure TestFlexGap;
    procedure TestFlexGrow;
    procedure TestFlexShrink;
    procedure TestJustifyContent;
    procedure TestAlignItems;
    procedure TestAlignSelf;
    procedure TestFlexColumn;
    procedure TestFlexColumnJustifyCenter;
    procedure TestFlexDisplayNoneIsSkipped;
    procedure TestFlexWrap;
    procedure TestFlexAutoMargin;
    procedure TestFlexOrder;
    procedure TestFlexRowReverse;
    procedure TestNestedFlexShrinkToFit;
    procedure TestNestedFlexGrowLayoutsChildren;
    procedure TestFlexMaxWidth;
    procedure TestFlexMinContent;
    procedure TestAbsoluteBottomInAutoHeight;
    procedure TestAbsoluteInPaddingBox;
  end;

implementation

function TTestLayout.Add(AParent: THtmlNode; const AStyle: String): THtmlNode;
begin
  Result := HTMLDiv(AStyle).AppendTo(AParent);
end;

procedure TTestLayout.Layout(AWidth: Integer; AHeight: Integer);
begin
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, AWidth, AHeight);
end;

procedure TTestLayout.CheckBox(const AMsg: String; ANode: THtmlNode; ALeft, ATop, AWidth, AHeight: Integer);
var
  R: TRect;
begin
  R := ANode.CompSize.ContentRect;   // border box
  AssertEquals(AMsg + ' left', ALeft, R.Left);
  AssertEquals(AMsg + ' top', ATop, R.Top);
  if AWidth >= 0 then AssertEquals(AMsg + ' width', AWidth, R.Right - R.Left);
  if AHeight >= 0 then AssertEquals(AMsg + ' height', AHeight, R.Bottom - R.Top);
end;

procedure TTestLayout.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestLayout.TearDown;
begin
  FRoot.Free;
end;

procedure TTestLayout.TestBlocksFillWidth;
var
  A, B: THtmlNode;
begin
  A := Add(FRoot, 'height: 10px');
  B := Add(FRoot, 'height: 20px; margin: 5px');
  Layout(300);
  CheckBox('A', A, 0, 0, 300, 10);
  CheckBox('B', B, 5, 15, 290, 20);
end;

procedure TTestLayout.TestBoxSizing;
var
  A, B: THtmlNode;
begin
  A := Add(FRoot, 'width: 100px; height: 10px; padding: 10px; border: 2px solid');
  B := Add(FRoot, 'width: 100px; height: 10px; padding: 10px; border: 2px solid; box-sizing: border-box');
  Layout(300);
  CheckBox('content-box', A, 0, 0, 124, 34);
  CheckBox('border-box', B, 0, 34, 100, 24);
end;

procedure TTestLayout.TestBorderWithoutStyleHasNoWidth;
var
  A: THtmlNode;
begin
  A := Add(FRoot, 'width: 100px; height: 10px; border-width: 5px');
  Layout(300);
  CheckBox('A', A, 0, 0, 100, 10);
end;

procedure TTestLayout.TestMarginAutoCenters;
var
  A, B: THtmlNode;
begin
  A := Add(FRoot, 'width: 100px; height: 10px; margin: 0 auto');
  B := Add(FRoot, 'width: 100px; height: 10px; margin-left: auto');
  Layout(300);
  CheckBox('center', A, 100, 0, 100, 10);
  CheckBox('right', B, 200, 10, 100, 10);
end;

procedure TTestLayout.TestMaxWidthWithMarginAuto;
var
  A: THtmlNode;
begin
  A := Add(FRoot, 'max-width: 100px; height: 10px; margin: 0 auto');
  Layout(300);
  CheckBox('A', A, 100, 0, 100, 10);
end;

procedure TTestLayout.TestMinWidth;
var
  A: THtmlNode;
begin
  A := Add(FRoot, 'width: 10px; min-width: 50px; height: 10px');
  Layout(300);
  CheckBox('A', A, 0, 0, 50, 10);
end;

procedure TTestLayout.TestEmRemUnits;
var
  A, B: THtmlNode;
begin
  A := Add(FRoot, 'font-size: 10px; width: 2em; height: 1em');
  B := Add(FRoot, 'font-size: 10px; width: 2rem; height: 0.5rem');
  Layout(300);
  CheckBox('em', A, 0, 0, 20, 10);
  CheckBox('rem', B, 0, 10, 32, 8);
end;

procedure TTestLayout.TestPixelRatio;
var
  A: THtmlNode;
begin
  FRoot.PixelRatio := 2;
  A := Add(FRoot, 'width: 10px; height: 5px; margin-left: 1px');
  Layout(300);
  CheckBox('A', A, 2, 0, 20, 10);
end;

procedure TTestLayout.TestAbsoluteRightBottom;
var
  P, A, B: THtmlNode;
begin
  P := Add(FRoot, 'position: relative; width: 200px; height: 100px');
  A := Add(P, 'position: absolute; right: 10px; bottom: 10px; width: 20px; height: 20px');
  B := Add(P, 'position: absolute; left: 5px; top: 6px; width: 20px; height: 20px');
  Layout(300);
  CheckBox('right/bottom', A, 170, 70, 20, 20);
  CheckBox('left/top', B, 5, 6, 20, 20);
end;

procedure TTestLayout.TestRelativeOffset;
var
  A: THtmlNode;
begin
  A := Add(FRoot, 'position: relative; left: 5px; top: 7px; width: 20px; height: 20px');
  Layout(300);
  CheckBox('A', A, 5, 7, 20, 20);
end;

procedure TTestLayout.TestFloatRight;
var
  A, B: THtmlNode;
begin
  A := Add(FRoot, 'float: right; width: 50px; height: 10px');
  B := Add(FRoot, 'float: right; width: 50px; height: 10px');
  Layout(300);
  CheckBox('A', A, 250, 0, 50, 10);
  CheckBox('B', B, 200, 0, 50, 10);
end;

procedure TTestLayout.TestFlexRow;
var
  F, A, B, C: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'width: 50px; height: 10px');
  B := Add(F, 'width: 50px; height: 20px');
  C := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('F', F, 0, 0, 300, 20);
  CheckBox('A', A, 0, 0, 50, 10);   // fixed height is not stretched
  CheckBox('B', B, 50, 0, 50, 20);
  CheckBox('C', C, 100, 0, 50, 10);
end;

procedure TTestLayout.TestFlexGap;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; gap: 10px');
  A := Add(F, 'width: 50px; height: 10px');
  B := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('A', A, 0, 0, 50, 10);
  CheckBox('B', B, 60, 0, 50, 10);
end;

procedure TTestLayout.TestFlexGrow;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'flex: 1; height: 10px');
  B := Add(F, 'flex: 2; height: 10px');
  Layout(300);
  CheckBox('A', A, 0, 0, 100, 10);
  CheckBox('B', B, 100, 0, 200, 10);
end;

procedure TTestLayout.TestFlexShrink;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; width: 100px');
  A := Add(F, 'width: 80px; height: 10px');
  B := Add(F, 'width: 80px; height: 10px');
  Layout(300);
  CheckBox('A', A, 0, 0, 50, 10);
  CheckBox('B', B, 50, 0, 50, 10);
  A.InlineStyle := 'width: 80px; height: 10px; flex-shrink: 0';
  Layout(300);
  CheckBox('A no shrink', A, 0, 0, 80, 10);
  CheckBox('B shrink', B, 80, 0, 20, 10);
end;

procedure TTestLayout.TestJustifyContent;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; justify-content: center');
  A := Add(F, 'width: 50px; height: 10px');
  B := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('center A', A, 100, 0, 50, 10);
  CheckBox('center B', B, 150, 0, 50, 10);
  F.InlineStyle := 'display: flex; justify-content: space-between';
  Layout(300);
  CheckBox('between A', A, 0, 0, 50, 10);
  CheckBox('between B', B, 250, 0, 50, 10);
  F.InlineStyle := 'display: flex; justify-content: flex-end';
  Layout(300);
  CheckBox('end A', A, 200, 0, 50, 10);
  F.InlineStyle := 'display: flex; justify-content: space-evenly';
  Layout(300);
  CheckBox('evenly A', A, 66, 0, 50, 10);
  CheckBox('evenly B', B, 182, 0, 50, 10);
end;

procedure TTestLayout.TestAlignItems;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; height: 100px; align-items: center');
  A := Add(F, 'width: 50px; height: 20px');
  B := Add(F, 'width: 50px');
  Layout(300);
  CheckBox('center', A, 0, 40, 50, 20);
  F.InlineStyle := 'display: flex; height: 100px; align-items: flex-end';
  Layout(300);
  CheckBox('end', A, 0, 80, 50, 20);
  F.InlineStyle := 'display: flex; height: 100px';
  Layout(300);
  CheckBox('stretch fixed', A, 0, 0, 50, 20);
  CheckBox('stretch auto', B, 50, 0, 50, 100);
end;

procedure TTestLayout.TestAlignSelf;
var
  F, A: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; height: 100px; align-items: flex-start');
  A := Add(F, 'width: 50px; height: 20px; align-self: flex-end');
  Layout(300);
  CheckBox('A', A, 0, 80, 50, 20);
end;

procedure TTestLayout.TestFlexColumn;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; flex-direction: column; width: 200px; gap: 5px');
  A := Add(F, 'height: 30px');
  B := Add(F, 'height: 30px; width: 50px');
  Layout(300);
  CheckBox('F', F, 0, 0, 200, 65);
  CheckBox('A', A, 0, 0, 200, 30);
  CheckBox('B', B, 0, 35, 50, 30);
end;

procedure TTestLayout.TestFlexColumnJustifyCenter;
var
  F, A: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; flex-direction: column; height: 100px; justify-content: center; align-items: center');
  A := Add(F, 'height: 20px; width: 20px');
  Layout(300);
  CheckBox('A', A, 140, 40, 20, 20);
end;

procedure TTestLayout.TestFlexDisplayNoneIsSkipped;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'width: 50px; height: 10px; display: none');
  B := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('B', B, 0, 0, 50, 10);
end;

procedure TTestLayout.TestFlexWrap;
var
  F, A, B, C: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; flex-wrap: wrap; width: 100px; gap: 4px');
  A := Add(F, 'width: 60px; height: 10px');
  B := Add(F, 'width: 60px; height: 20px');
  C := Add(F, 'width: 30px; height: 20px');
  Layout(300);
  CheckBox('A', A, 0, 0, 60, 10);
  CheckBox('B', B, 0, 14, 60, 20);
  CheckBox('C', C, 64, 14, 30, 20);
  CheckBox('F', F, 0, 0, 100, 34);
end;

procedure TTestLayout.TestFlexAutoMargin;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'width: 50px; height: 10px');
  B := Add(F, 'width: 50px; height: 10px; margin-left: auto');
  Layout(300);
  CheckBox('A', A, 0, 0, 50, 10);
  CheckBox('B', B, 250, 0, 50, 10);
end;

procedure TTestLayout.TestFlexOrder;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'width: 50px; height: 10px; order: 2');
  B := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('A', A, 50, 0, 50, 10);
  CheckBox('B', B, 0, 0, 50, 10);
end;

procedure TTestLayout.TestFlexRowReverse;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; flex-direction: row-reverse');
  A := Add(F, 'width: 50px; height: 10px');
  B := Add(F, 'width: 50px; height: 10px');
  Layout(300);
  CheckBox('A', A, 250, 0, 50, 10);
  CheckBox('B', B, 200, 0, 50, 10);
end;

procedure TTestLayout.TestNestedFlexShrinkToFit;
var
  F, Inner, A, B, C: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; align-items: flex-start');
  Inner := Add(F, 'display: flex; padding: 5px');
  A := Add(Inner, 'width: 20px; height: 10px');
  B := Add(Inner, 'width: 20px; height: 10px');
  C := Add(F, 'width: 30px; height: 10px');
  Layout(300);
  CheckBox('Inner', Inner, 0, 0, 50, 20);
  CheckBox('A', A, 5, 5, 20, 10);
  CheckBox('B', B, 25, 5, 20, 10);
  CheckBox('C', C, 50, 0, 30, 10);
end;

procedure TTestLayout.TestNestedFlexGrowLayoutsChildren;
var
  F, Inner, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  Inner := Add(F, 'display: flex; flex-grow: 1; justify-content: space-between');
  A := Add(Inner, 'width: 20px; height: 10px');
  B := Add(Inner, 'width: 20px; height: 10px');
  Layout(300);
  CheckBox('Inner', Inner, 0, 0, 300, 10);
  CheckBox('A', A, 0, 0, 20, 10);
  CheckBox('B', B, 280, 0, 20, 10);
end;

procedure TTestLayout.TestFlexMaxWidth;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  A := Add(F, 'flex-grow: 1; max-width: 100px; height: 10px');
  B := Add(F, 'flex-grow: 1; height: 10px');
  Layout(300);
  CheckBox('A', A, 0, 0, 100, 10);
  CheckBox('B', B, 100, 0, 200, 10);
end;

procedure TTestLayout.TestFlexMinContent;
var
  F, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex; width: 100px');
  A := HTMLNode('', 'Supercalifragilisticexpialidocious').AppendTo(F);
  B := HTMLNode('', 'Supercalifragilisticexpialidocious').AppendTo(F);
  Layout(300);
  AssertTrue('min-content keeps word width', A.CompSize.ContentRect.Width > 50);
  AssertTrue('no overlap', B.CompSize.ContentRect.Left >= A.CompSize.ContentRect.Right);
  A.InlineStyle := 'min-width: 0';
  B.InlineStyle := 'min-width: 0';
  Layout(300);
  CheckBox('A min-width 0', A, 0, 0, 50, -1);
  CheckBox('B min-width 0', B, 50, 0, 50, -1);
end;

procedure TTestLayout.TestAbsoluteInPaddingBox;
var
  P, A, B: THtmlNode;
begin
  // containing block of absolute node is padding box of parent
  P := Add(FRoot, 'position: relative; padding: 10px; height: 50px');
  A := Add(P, 'position: absolute; left: 0; top: 0; width: 5px; height: 5px');
  B := Add(P, 'position: absolute; right: 0; bottom: 0; width: 5px; height: 5px');
  Layout(300);
  CheckBox('left top', A, 0, 0, 5, 5);
  CheckBox('right bottom', B, 295, 65, 5, 5);
end;

procedure TTestLayout.TestAbsoluteBottomInAutoHeight;
var
  F, A, P, C: THtmlNode;
begin
  // container height depends on content, absolute child with bottom is placed after height is known
  F := Add(FRoot, 'display: flex; flex-direction: column; position: relative');
  Add(F, 'height: 50px');
  A := Add(F, 'position: absolute; bottom: 0; right: 10px; width: 20px; height: 10px');
  P := Add(FRoot, 'position: relative');
  Add(P, 'height: 40px');
  C := Add(P, 'position: absolute; bottom: 5px; left: 3px; width: 20px; height: 10px');
  Layout(300);
  CheckBox('flex absolute', A, 270, 40, 20, 10);
  CheckBox('block absolute', C, 3, 50 + 25, 20, 10);
end;

initialization
  RegisterTest(TTestLayout);
end.
