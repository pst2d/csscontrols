unit test_grid;

(*
  Grid layout (subset): tracks, automatic placement, spans, gaps, alignment
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestGrid }

  TTestGrid = class(TTestCase)
  private
    FRoot: THtmlNode;
    function Add(AParent: THtmlNode; const AStyle: String): THtmlNode;
    procedure Layout(AWidth: Integer; AHeight: Integer = -1);
    procedure CheckBox(const AMsg: String; ANode: THtmlNode; ALeft, ATop, AWidth, AHeight: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEqualColumns;
    procedure TestFixedAndFrColumns;
    procedure TestAutoColumn;
    procedure TestRowHeightIsTallestItem;
    procedure TestColumnSpan;
    procedure TestRowSpan;
    procedure TestAlignCenter;
    procedure TestFixedRows;
    procedure TestTailwindGrid;
    procedure TestGridInFlex;
  end;

implementation

function TTestGrid.Add(AParent: THtmlNode; const AStyle: String): THtmlNode;
begin
  Result := HTMLDiv(AStyle).AppendTo(AParent);
end;

procedure TTestGrid.Layout(AWidth: Integer; AHeight: Integer);
begin
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, AWidth, AHeight);
end;

procedure TTestGrid.CheckBox(const AMsg: String; ANode: THtmlNode; ALeft, ATop, AWidth, AHeight: Integer);
var
  R: TRect;
begin
  R := ANode.CompSize.ContentRect;
  AssertEquals(AMsg + ' left', ALeft, R.Left);
  AssertEquals(AMsg + ' top', ATop, R.Top);
  if AWidth >= 0 then AssertEquals(AMsg + ' width', AWidth, R.Right - R.Left);
  if AHeight >= 0 then AssertEquals(AMsg + ' height', AHeight, R.Bottom - R.Top);
end;

procedure TTestGrid.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestGrid.TearDown;
begin
  FRoot.Free;
end;

procedure TTestGrid.TestEqualColumns;
var
  G: THtmlNode;
  I: Integer;
  A: array[0..4] of THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px');
  for I := 0 to 4 do A[I] := Add(G, 'height: 20px');
  Layout(320);
  CheckBox('1', A[0], 0, 0, 100, 20);
  CheckBox('2', A[1], 110, 0, 100, 20);
  CheckBox('3', A[2], 220, 0, 100, 20);
  CheckBox('4 (next row)', A[3], 0, 30, 100, 20);
  CheckBox('5', A[4], 110, 30, 100, 20);
  AssertEquals('grid height', 50, G.CompSize.ContentRect.Bottom - G.CompSize.ContentRect.Top);
end;

procedure TTestGrid.TestFixedAndFrColumns;
var
  G, A, B, C: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: 100px 1fr 2fr');
  A := Add(G, 'height: 10px');
  B := Add(G, 'height: 10px');
  C := Add(G, 'height: 10px');
  Layout(400);
  CheckBox('fixed', A, 0, 0, 100, 10);
  CheckBox('1fr', B, 100, 0, 100, 10);
  CheckBox('2fr', C, 200, 0, 200, 10);
end;

procedure TTestGrid.TestAutoColumn;
var
  G, A, B: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: auto 1fr; column-gap: 8px');
  A := Add(G, 'height: 10px');
  Add(A, 'width: 60px; height: 10px');
  B := Add(G, 'height: 10px');
  Layout(300);
  CheckBox('auto = content width', A, 0, 0, 60, 10);
  CheckBox('rest', B, 68, 0, 232, 10);
end;

procedure TTestGrid.TestRowHeightIsTallestItem;
var
  G, A, B: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: 1fr 1fr');
  A := Add(G, 'height: 10px');
  B := Add(G, '');
  Add(B, 'height: 40px');
  Layout(200);
  CheckBox('stretched to row', A, 0, 0, 100, 10);       // explicit height is kept
  CheckBox('tall', B, 100, 0, 100, 40);
  A.InlineStyle := '';
  Add(A, 'height: 10px');
  Layout(200);
  CheckBox('auto height is stretched', A, 0, 0, 100, 40);
end;

procedure TTestGrid.TestColumnSpan;
var
  G, A, B, C: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: repeat(3, 1fr); gap: 0');
  A := Add(G, 'height: 10px; grid-column: span 2 / span 2');
  B := Add(G, 'height: 10px; grid-column: span 2 / span 2');   // doesn't fit in first row
  C := Add(G, 'height: 10px; grid-column: 1 / -1');
  Layout(300);
  CheckBox('span 2', A, 0, 0, 200, 10);
  CheckBox('next row', B, 0, 10, 200, 10);
  CheckBox('full row', C, 0, 20, 300, 10);
end;

procedure TTestGrid.TestRowSpan;
var
  G, A, B, C: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: 1fr 1fr; row-gap: 10px');
  A := Add(G, 'grid-row: span 2 / span 2');
  B := Add(G, 'height: 20px');
  C := Add(G, 'height: 20px');
  Layout(200);
  CheckBox('two rows', A, 0, 0, 100, 50);
  CheckBox('first row', B, 100, 0, 100, 20);
  CheckBox('second row next to span', C, 100, 30, 100, 20);
end;

procedure TTestGrid.TestAlignCenter;
var
  G, A, B: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: 1fr 1fr; align-items: center');
  A := Add(G, 'height: 10px');
  B := Add(G, 'height: 30px');
  Layout(200);
  CheckBox('centered', A, 0, 10, 100, 10);
  CheckBox('tall', B, 100, 0, 100, 30);
end;

procedure TTestGrid.TestFixedRows;
var
  G, A, B: THtmlNode;
begin
  G := Add(FRoot, 'display: grid; grid-template-columns: 1fr; grid-template-rows: 50px 1fr; height: 200px');
  A := Add(G, '');
  B := Add(G, '');
  Layout(100);
  CheckBox('fixed row', A, 0, 0, 100, 50);
  CheckBox('fr row fills rest', B, 0, 50, 100, 150);
end;

procedure TTestGrid.TestTailwindGrid;
var
  G, A, B, C: THtmlNode;
begin
  CSSTailwindEnable;
  try
    G := HTMLNode('grid grid-cols-4 gap-4').AppendTo(FRoot);
    A := HTMLNode('col-span-3 h-4').AppendTo(G);
    B := HTMLNode('h-4').AppendTo(G);
    C := HTMLNode('col-span-full h-4').AppendTo(G);
    Layout(448);
    CheckBox('col-span-3', A, 0, 0, 332, 16);
    CheckBox('last column', B, 348, 0, 100, 16);
    CheckBox('col-span-full', C, 0, 32, 448, 16);
    G.SetClass('grid grid-cols-[100px_1fr] gap-4');
    Layout(448);
    CheckBox('arbitrary columns (span is limited to 2 columns)', B, 0, 32, 100, 16);
  finally
    CSSTailwindDisable;
  end;
end;

procedure TTestGrid.TestGridInFlex;
var
  F, G, A, B: THtmlNode;
begin
  F := Add(FRoot, 'display: flex');
  G := Add(F, 'flex: 1; display: grid; grid-template-columns: 1fr 1fr');
  A := Add(G, 'height: 10px');
  B := Add(G, 'height: 10px');
  Add(F, 'width: 100px; height: 10px');
  Layout(300);
  CheckBox('grid is flex item', G, 0, 0, 200, 10);
  CheckBox('A', A, 0, 0, 100, 10);
  CheckBox('B', B, 100, 0, 100, 10);
end;

initialization
  RegisterTest(TTestGrid);
end.
