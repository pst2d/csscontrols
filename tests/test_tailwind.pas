unit test_tailwind;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestTailwind }

  TTestTailwind = class(TTestCase)
  private
    FRoot: THtmlNode;
    procedure CheckResolve(const AClass, AExpected: String);
    procedure CheckUnknown(const AClass: String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSpacing;
    procedure TestSizing;
    procedure TestColors;
    procedure TestTypography;
    procedure TestBorders;
    procedure TestArbitraryValues;
    procedure TestUnknownClasses;
    procedure TestLonghandWinsOverShorthand;
    procedure TestHoverVariant;
    procedure TestResponsiveVariants;
    procedure TestFirstLastVariants;
    procedure TestGroupHover;
    procedure TestStyleSheetAndUtilities;
    procedure TestCardLayout;
  end;

implementation

procedure TTestTailwind.CheckResolve(const AClass, AExpected: String);
var
  D: String;
  O: Integer;
begin
  AssertTrue(AClass + ' resolved', TailwindResolve(AClass, D, O));
  AssertEquals(AClass, AExpected, D);
end;

procedure TTestTailwind.CheckUnknown(const AClass: String);
var
  D: String;
  O: Integer;
begin
  AssertFalse(AClass + ' should be unknown', TailwindResolve(AClass, D, O));
end;

procedure TTestTailwind.SetUp;
begin
  CSSTailwindEnable;
  FRoot := THtmlNode.Create;
end;

procedure TTestTailwind.TearDown;
begin
  FRoot.Free;
  CSSTailwindDisable;
end;

procedure TTestTailwind.TestSpacing;
begin
  CheckResolve('p-4', 'padding:1rem');
  CheckResolve('px-2.5', 'padding-left:0.625rem;padding-right:0.625rem');
  CheckResolve('pt-px', 'padding-top:1px');
  CheckResolve('m-0', 'margin:0px');
  CheckResolve('mx-auto', 'margin-left:auto;margin-right:auto');
  CheckResolve('-mt-2', 'margin-top:-0.5rem');
  CheckResolve('gap-x-3', 'column-gap:0.75rem');
  CheckUnknown('-p-2');
end;

procedure TTestTailwind.TestSizing;
begin
  CheckResolve('w-1/2', 'width:50%');
  CheckResolve('w-full', 'width:100%');
  CheckResolve('h-10', 'height:2.5rem');
  CheckResolve('size-8', 'width:2rem;height:2rem');
  CheckResolve('max-w-md', 'max-width:28rem');
  CheckResolve('min-w-0', 'min-width:0px');
  CheckResolve('basis-1/3', 'flex-basis:33.333333%');
  CheckResolve('inset-0', 'inset:0px');
  CheckResolve('-left-1/2', 'left:-50%');
end;

procedure TTestTailwind.TestColors;
begin
  CheckResolve('bg-blue-500', 'background-color:#3b82f6');
  CheckResolve('text-slate-950', 'color:#020617');
  CheckResolve('bg-white', 'background-color:#ffffff');
  CheckResolve('bg-transparent', 'background-color:transparent');
  CheckResolve('text-red-500/50', 'color:#ef4444');
  CheckUnknown('bg-blue-550');
end;

procedure TTestTailwind.TestTypography;
begin
  CheckResolve('text-sm', 'font-size:0.875rem');
  CheckResolve('font-semibold', 'font-weight:600');
  CheckResolve('text-center', 'text-align:center');
  CheckResolve('truncate', 'overflow:hidden;white-space:nowrap');
end;

procedure TTestTailwind.TestBorders;
begin
  CheckResolve('border-0', 'border-width:0px;border-style:solid;border-color:#e5e7eb');
  CheckResolve('border-t-2', 'border-top-width:2px;border-top-style:solid;border-top-color:#e5e7eb');
  CheckResolve('border-red-500', 'border-color:#ef4444');
  CheckResolve('rounded', 'border-radius:0.25rem');
  CheckResolve('rounded-full', 'border-radius:9999px');
  CheckResolve('rounded-t-lg', 'border-top-left-radius:0.5rem;border-top-right-radius:0.5rem');
  CheckResolve('rounded-br', 'border-bottom-right-radius:0.25rem');
end;

procedure TTestTailwind.TestArbitraryValues;
begin
  CheckResolve('w-[200px]', 'width:200px');
  CheckResolve('bg-[#ff8800]', 'background-color:#ff8800');
  CheckResolve('text-[13px]', 'font-size:13px');
  CheckResolve('text-[#123456]', 'color:#123456');
  CheckUnknown('grid-cols-[1fr_2fr]');
end;

procedure TTestTailwind.TestUnknownClasses;
begin
  CheckUnknown('my-component');
  CheckUnknown('shadow-lg');
  CheckUnknown('bg-');
end;

procedure TTestTailwind.TestLonghandWinsOverShorthand;
var
  A: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('px-2 p-4');
  AssertEquals(0.5, A.CompStyle.Padding[csLeft].Value, 0.001);
  AssertEquals(1, A.CompStyle.Padding[csTop].Value, 0.001);
end;

procedure TTestTailwind.TestHoverVariant;
var
  A: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('bg-blue-600 hover:bg-red-500');
  AssertEquals(RGBToColor($25, $63, $eb), A.CompStyle.Background.Color.Value);
  A.Hovered := True;
  A.ApplyStyle;
  AssertEquals(RGBToColor($ef, $44, $44), A.CompStyle.Background.Color.Value);
end;

procedure TTestTailwind.TestResponsiveVariants;
var
  A: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  FRoot.ViewportWidth := 700;
  A.SetClass('lg:w-3 w-1 md:w-2');
  AssertEquals(0.25, A.CompStyle.Width.Value, 0.001);
  FRoot.ViewportWidth := 800;
  A.ApplyStyle;
  AssertEquals(0.5, A.CompStyle.Width.Value, 0.001);
  FRoot.ViewportWidth := 1200;
  A.ApplyStyle;
  AssertEquals(0.75, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestTailwind.TestFirstLastVariants;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('first:mt-0 mt-4');
  B.SetClass('first:mt-0 mt-4');
  AssertEquals(0, A.CompStyle.Margin[csTop].Value, 0.001);
  AssertEquals(1, B.CompStyle.Margin[csTop].Value, 0.001);
end;

procedure TTestTailwind.TestGroupHover;
var
  G, C: THtmlNode;
begin
  G := HTMLDiv('').SetClass('group').AppendTo(FRoot);
  C := HTMLDiv('').AppendTo(G);
  C.SetClass('text-black group-hover:text-white');
  AssertEquals(clBlack, C.CompStyle.Color.Value);
  G.Hovered := True;
  FRoot.ApplyStyles;
  AssertEquals(clWhite, C.CompStyle.Color.Value);
end;

procedure TTestTailwind.TestStyleSheetAndUtilities;
var
  Sheet: TCSSStyleSheet;
  A: THtmlNode;
begin
  Sheet := TCSSStyleSheet.Create(nil);
  try
    Sheet.Style := '.btn { padding: 2px; color: red }';
    FRoot.StyleSheet := Sheet;
    A := HTMLDiv('').AppendTo(FRoot);
    A.SetClass('btn p-4');
    AssertEquals(1, A.CompStyle.Padding[csTop].Value, 0.001);      // utilities are after component styles
    AssertEquals(clRed, A.CompStyle.Color.Value);
    FRoot.StyleSheet := nil;
  finally
    Sheet.Free;
  end;
end;

procedure TTestTailwind.TestCardLayout;
var
  Card, Icon, Body, Btn: THtmlNode;
begin
  Card := HTMLDiv('').AppendTo(FRoot);
  Card.SetClass('flex items-center gap-4 p-4 max-w-sm mx-auto border rounded-xl');
  Icon := HTMLDiv('').AppendTo(Card);
  Icon.SetClass('size-12 shrink-0 rounded-full bg-blue-500');
  Body := HTMLDiv('').AppendTo(Card);
  Body.SetClass('grow h-6');
  Btn := HTMLDiv('').AppendTo(Card);
  Btn.SetClass('w-16 h-8 ml-auto');
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, 600, -1);
  // max-w-sm = 24rem = 384px, centered in 600px
  AssertEquals('card left', 108, Card.CompSize.ContentRect.Left);
  AssertEquals('card width', 384, Card.CompSize.ContentRect.Width);
  // border 1px + padding 16px
  AssertEquals('icon left', 108 + 17, Icon.CompSize.ContentRect.Left);
  AssertEquals('icon size', 48, Icon.CompSize.ContentRect.Width);
  AssertEquals('card height', 48 + 34, Card.CompSize.ContentRect.Height);
  AssertEquals('body vertical center', 17 + 12, Body.CompSize.ContentRect.Top);
  AssertEquals('button right', 108 + 384 - 17, Btn.CompSize.ContentRect.Right);
end;

initialization
  RegisterTest(TTestTailwind);
end.
