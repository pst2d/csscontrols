unit test_cascade;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpcunit, testregistry, cssbase;

type

  { TTestCascade }

  TTestCascade = class(TTestCase)
  private
    FRoot: THtmlNode;
    FSheet: TCSSStyleSheet;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSelectorParsing;
    procedure TestStyleSheetOrderWins;
    procedure TestSpecificityWins;
    procedure TestIdElementUniversal;
    procedure TestDescendantAndChild;
    procedure TestHoverIsRemoved;
    procedure TestFirstLastChild;
    procedure TestEscapedClassNames;
    procedure TestInlineStyleWins;
    procedure TestSetInlineStyleKeepsClassStyles;
    procedure TestInheritance;
  end;

implementation

procedure TTestCascade.SetUp;
begin
  FSheet := TCSSStyleSheet.Create(nil);
  FRoot := THtmlNode.Create;
  FRoot.StyleSheet := FSheet;
end;

procedure TTestCascade.TearDown;
begin
  FRoot.Free;
  FSheet.Free;
end;

procedure TTestCascade.TestSelectorParsing;
var
  Sel: TCSSCompoundSelectors;
  Spec: Integer;
begin
  Sel := ParseSelector('div.a.b:hover > #x .c', Spec);
  AssertEquals(3, Length(Sel));
  AssertEquals('div', Sel[0].Element);
  AssertEquals(2, Length(Sel[0].Classes));
  AssertEquals('hover', Sel[0].Pseudos[0]);
  AssertTrue(Sel[1].Combinator = ccChild);
  AssertEquals('x', Sel[1].Id);
  AssertTrue(Sel[2].Combinator = ccDescendant);
  AssertEquals(10000 + 4 * 100 + 1, Spec);
  AssertEquals(0, Length(ParseSelector('a + b', Spec)));
  AssertEquals(0, Length(ParseSelector('p::before', Spec)));
end;

procedure TTestCascade.TestStyleSheetOrderWins;
var
  A: THtmlNode;
begin
  FSheet.Style := '.b { width: 2px } .a { width: 1px }';
  A := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('a b');
  AssertEquals(1, A.CompStyle.Width.Value, 0.001);
  FSheet.Style := '.a { width: 1px } .b { width: 2px }';
  A.ApplyStyle;
  AssertEquals(2, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestCascade.TestSpecificityWins;
var
  A: THtmlNode;
begin
  FSheet.Style := '#x { width: 3px } .a.b { width: 2px } .a { width: 1px } div { width: 9px }';
  A := HTMLDiv('', 'x').AppendTo(FRoot);
  A.SetClass('a b');
  AssertEquals(3, A.CompStyle.Width.Value, 0.001);
  A.Id := 'y';
  A.ApplyStyle;
  AssertEquals(2, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestCascade.TestIdElementUniversal;
var
  A, S: THtmlNode;
begin
  FSheet.Style := '* { height: 1px } span { width: 4px } #s { color: red }';
  A := HTMLDiv('').AppendTo(FRoot);
  S := HTMLSpan('', 'x', 's').AppendTo(FRoot);
  FRoot.ApplyStyles;
  AssertEquals(1, A.CompStyle.Height.Value, 0.001);
  AssertTrue(A.CompStyle.Width.LengthType = cltUndefined);
  AssertEquals(4, S.CompStyle.Width.Value, 0.001);
  AssertEquals(clRed, S.CompStyle.Color.Value);
  AssertTrue(S.CompStyle.Display = cdtInline);
end;

procedure TTestCascade.TestDescendantAndChild;
var
  A, B, C: THtmlNode;
begin
  FSheet.Style := '.p .c { width: 1px } .p > .c { height: 2px }';
  A := HTMLDiv('').SetClass('p').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(A);
  C := HTMLDiv('').SetClass('c').AppendTo(B);
  FRoot.ApplyStyles;
  AssertEquals(1, C.CompStyle.Width.Value, 0.001);
  AssertTrue(C.CompStyle.Height.LengthType = cltUndefined);
  B.SetClass('c');
  AssertEquals(2, B.CompStyle.Height.Value, 0.001);
end;

procedure TTestCascade.TestHoverIsRemoved;
var
  A: THtmlNode;
begin
  FSheet.Style := '.a { width: 1px } .a:hover { border-radius: 5px; position: relative; width: 2px }';
  A := HTMLDiv('').SetClass('a').AppendTo(FRoot);
  A.Hovered := True;
  A.ApplyStyle;
  AssertEquals(2, A.CompStyle.Width.Value, 0.001);
  AssertTrue(A.CompStyle.Position = cpRelative);
  A.Hovered := False;
  A.ApplyStyle;
  AssertEquals(1, A.CompStyle.Width.Value, 0.001);
  AssertTrue(A.CompStyle.Position = cpStatic);
  AssertTrue(A.CompStyle.RadiusTopLeft.Width.LengthType = cltUndefined);
end;

procedure TTestCascade.TestFirstLastChild;
var
  A, B, C: THtmlNode;
begin
  FSheet.Style := '.i:first-child { width: 1px } .i:last-child { height: 1px }';
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(FRoot);
  C := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('i'); B.SetClass('i'); C.SetClass('i');
  AssertTrue(A.CompStyle.Width.LengthType = cltPx);
  AssertTrue(B.CompStyle.Width.LengthType = cltUndefined);
  AssertTrue(B.CompStyle.Height.LengthType = cltUndefined);
  AssertTrue(C.CompStyle.Height.LengthType = cltPx);
end;

procedure TTestCascade.TestEscapedClassNames;
var
  A: THtmlNode;
begin
  FSheet.Style := '.w-1\/2 { width: 50% } .hover\:w-full:hover { width: 100% }';
  A := HTMLDiv('').SetClass('w-1/2 hover:w-full').AppendTo(FRoot);
  A.ApplyStyle;
  AssertEquals(50, A.CompStyle.Width.Value, 0.001);
  A.Hovered := True;
  A.ApplyStyle;
  AssertEquals(100, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestCascade.TestInlineStyleWins;
var
  A: THtmlNode;
begin
  FSheet.Style := '#a.x { width: 1px }';
  A := HTMLDiv('width: 7px', 'a').SetClass('x').AppendTo(FRoot);
  A.ApplyStyle;
  AssertEquals(7, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestCascade.TestSetInlineStyleKeepsClassStyles;
var
  A: THtmlNode;
begin
  FSheet.Style := '.x { height: 3px }';
  A := HTMLDiv('').AppendTo(FRoot);
  A.SetClass('x');
  A.InlineStyle := 'width: 1px';
  AssertEquals(3, A.CompStyle.Height.Value, 0.001);
  AssertEquals(1, A.CompStyle.Width.Value, 0.001);
end;

procedure TTestCascade.TestInheritance;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('color: red; text-align: center; font-size: 20px; font-weight: bold').AppendTo(FRoot);
  B := HTMLSpan('font-size: 0.5em', 'text').AppendTo(A);
  FRoot.LayoutTo(0, 0, 200, -1);
  AssertEquals(clRed, B.CompStyle.Color.Value);
  AssertTrue(B.CompStyle.TextAlign = ctaCenter);
  AssertTrue(B.CompStyle.Font.Weight.FontType = cfwBold);
  AssertEquals(10, B.CompSize.FontSize, 0.001);
  // parent changes, child must follow (no stale inherited values)
  A.InlineStyle := 'color: blue; font-size: 30px';
  FRoot.LayoutTo(0, 0, 200, -1);
  AssertEquals(clBlue, B.CompStyle.Color.Value);
  AssertTrue(B.CompStyle.TextAlign = ctaUndefined);
  AssertTrue(B.CompStyle.Font.Weight.FontType <> cfwBold);
  AssertEquals(15, B.CompSize.FontSize, 0.001);
end;

initialization
  RegisterTest(TTestCascade);
end.
