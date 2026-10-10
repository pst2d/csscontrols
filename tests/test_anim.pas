unit test_anim;

(*
  Transitions, built-in animations, opacity and pointer-events
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, fpcunit, testregistry, cssbase, csstailwind;

type

  { TTestAnim }

  TTestAnim = class(TTestCase)
  private
    FRoot: THtmlNode;
    procedure Layout;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestColorTransition;
    procedure TestNoTransitionWithoutDuration;
    procedure TestTransformTransition;
    procedure TestOpacityUsesBitmap;
    procedure TestSpinAnimation;
    procedure TestPointerEventsNone;
    procedure TestParseTransition;
    procedure TestTailwindClasses;
    procedure TestNoTransitionBeforePaint;
  end;

implementation

// styles, layout and paint (transitions start only for painted nodes)
procedure TTestAnim.Layout;
var
  Bmp: TBitmap;
begin
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, 200, 200);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(200, 200);
    FRoot.PaintTo(Bmp.Canvas);
  finally
    Bmp.Free;
  end;
end;

procedure TTestAnim.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestAnim.TearDown;
begin
  FRoot.Free;
end;

procedure TTestAnim.TestColorTransition;
var
  A: THtmlNode;
  C: TColor;
begin
  A := HTMLDiv('width: 50px; height: 50px; background-color: #ff0000; transition: background-color 100ms linear').AppendTo(FRoot);
  Layout;
  AssertFalse('nothing animates after first styles', FRoot.Animating);
  A.InlineStyle := 'width: 50px; height: 50px; background-color: #0000ff; transition: background-color 100ms linear';
  Layout;
  AssertTrue('transition started', FRoot.Animating);
  AssertEquals('starts with old color', $0000FF, ColorToRGB(A.CompStyle.Background.Color.Value));   // TColor is BGR: red
  FRoot.AnimationTick(GetTickCount64 + 50);
  C := ColorToRGB(A.CompStyle.Background.Color.Value);
  AssertTrue('middle: red and blue', (Red(C) > 80) and (Red(C) < 180) and (Blue(C) > 80) and (Blue(C) < 180));
  FRoot.AnimationTick(GetTickCount64 + 200);
  AssertEquals('end color', $FF0000, ColorToRGB(A.CompStyle.Background.Color.Value));
  FRoot.AnimationTick(GetTickCount64 + 210);
  AssertFalse('finished', FRoot.Animating);
end;

procedure TTestAnim.TestNoTransitionWithoutDuration;
var
  A: THtmlNode;
begin
  A := HTMLDiv('background-color: red').AppendTo(FRoot);
  Layout;
  A.InlineStyle := 'background-color: blue';
  Layout;
  AssertFalse('no transition', FRoot.Animating);
  AssertEquals('new color', clBlue, ColorToRGB(A.CompStyle.Background.Color.Value));
end;

procedure TTestAnim.TestTransformTransition;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 50px; height: 50px; transition: transform 100ms linear').AppendTo(FRoot);
  Layout;
  A.InlineStyle := 'width: 50px; height: 50px; transition: transform 100ms linear; transform: translateX(40px)';
  Layout;
  AssertTrue('transition started', FRoot.Animating);
  AssertTrue('starts at old position', Abs(A.TransformMatrix.E) < 1);
  FRoot.AnimationTick(GetTickCount64 + 50);
  AssertTrue('middle', (A.TransformMatrix.E > 10) and (A.TransformMatrix.E < 30));
  FRoot.AnimationTick(GetTickCount64 + 200);
  AssertEquals('end', 40, Round(A.TransformMatrix.E));
end;

procedure TTestAnim.TestOpacityUsesBitmap;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 50px; height: 50px; opacity: 0.5').AppendTo(FRoot);
  Layout;
  AssertTrue('opacity node is painted through bitmap', A.TransformKind = tkGeneral);
  A.InlineStyle := 'width: 50px; height: 50px; opacity: 50%';
  Layout;
  AssertEquals('percent', 0.5, A.CompStyle.Opacity, 0.001);
end;

procedure TTestAnim.TestSpinAnimation;
var
  A: THtmlNode;
begin
  A := HTMLDiv('width: 20px; height: 20px; animation: spin 1s linear infinite').AppendTo(FRoot);
  Layout;
  AssertTrue('animates', FRoot.Animating);
  FRoot.AnimationTick(GetTickCount64 + 250);
  AssertTrue('rotated', A.TransformKind = tkGeneral);
  A.InlineStyle := 'width: 20px; height: 20px';
  Layout;
  AssertFalse('stopped', FRoot.Animating);
end;

procedure TTestAnim.TestPointerEventsNone;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('width: 50px; height: 50px; pointer-events: none').AppendTo(FRoot);
  B := HTMLDiv('width: 20px; height: 20px').AppendTo(A);
  Layout;
  AssertFalse('node is ignored', A.HitTest(Point(10, 10)));
  AssertFalse('children too', B.HitTest(Point(10, 10)));
end;

procedure TTestAnim.TestParseTransition;
var
  Item: TCSSItem;
begin
  Item := TCSSItem.Create;
  try
    Item.Parse('transition: opacity 0.3s ease-in-out 50ms, transform 0.3s');
    AssertEquals('duration', 300, Item.TransitionDuration);
    AssertEquals('delay', 50, Item.TransitionDelay);
    AssertEquals('timing', 'ease-in-out', Item.TransitionTiming);
    AssertEquals('properties', 'opacity,transform', Item.TransitionProperty);
  finally
    Item.Free;
  end;
end;

procedure TTestAnim.TestTailwindClasses;
var
  A: THtmlNode;
begin
  CSSTailwindEnable;
  try
    A := HTMLNode('transition duration-300 ease-out opacity-40 animate-pulse pointer-events-none border-t-red-500').AppendTo(FRoot);
    Layout;
    AssertEquals('duration', 300, A.CompStyle.TransitionDuration);
    AssertEquals('ease-out', 'cubic-bezier(0, 0, 0.2, 1)', A.CompStyle.TransitionTiming);
    AssertTrue('animation', Pos('pulse', A.CompStyle.Animation) > 0);
    AssertTrue('pointer-events', A.CompStyle.PointerEventsNone);
    AssertTrue('border top color', A.CompStyle.Border[csTop].Color.ColorType = cctNormal);
  finally
    CSSTailwindDisable;
  end;
end;

procedure TTestAnim.TestNoTransitionBeforePaint;
var
  A: THtmlNode;
begin
  A := HTMLDiv('background-color: red; transition: background-color 100ms').AppendTo(FRoot);
  FRoot.ApplyStyles;
  A.InlineStyle := 'background-color: blue; transition: background-color 100ms';
  FRoot.ApplyStyles;
  AssertFalse('new node is not animated', FRoot.Animating);
end;

initialization
  RegisterTest(TTestAnim);
end.
