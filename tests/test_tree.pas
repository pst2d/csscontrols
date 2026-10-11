unit test_tree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, cssbase;

type

  { TTestTree }

  TTestTree = class(TTestCase)
  private
    FRoot: THtmlNode;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAddNode;
    procedure TestDeleteFirstMiddleLast;
    procedure TestClearKeepsSiblings;
    procedure TestMoveNodeToAnotherParent;
    procedure TestAddParentAsChildRaises;
    procedure TestGetElementsByClassName;
    procedure TestGetElementById;
    procedure TestClassList;
    procedure TestStyleValues;
    procedure TestUserData;
    procedure TestInsertBefore;
  end;

implementation

type
  TFreeSpy = class
    FFreed: PBoolean;
    destructor Destroy; override;
  end;

destructor TFreeSpy.Destroy;
begin
  FFreed^ := True;
  inherited Destroy;
end;

procedure TTestTree.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestTree.TearDown;
begin
  FRoot.Free;
end;

procedure TTestTree.TestAddNode;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(A);
  AssertEquals(1, FRoot.ChildCount);
  AssertTrue(B.RootNode = FRoot);
  AssertTrue(B.ParentNode = A);
  AssertTrue(FRoot.FirstChild = A);
end;

procedure TTestTree.TestDeleteFirstMiddleLast;
var
  A, B, C, D: THtmlNode;
begin
  A := HTMLDiv('', 'a').AppendTo(FRoot);
  B := HTMLDiv('', 'b').AppendTo(FRoot);
  C := HTMLDiv('', 'c').AppendTo(FRoot);
  D := HTMLDiv('', 'd').AppendTo(FRoot);
  HTMLDiv('').AppendTo(B);
  FRoot.Delete(B);
  AssertEquals(3, FRoot.ChildCount);
  AssertTrue(FRoot.FirstChild = A);
  AssertTrue(FRoot.GetNext(A) = C);
  FRoot.Delete(A);
  AssertTrue(FRoot.FirstChild = C);
  FRoot.Delete(D);
  AssertEquals(1, FRoot.ChildCount);
  AssertNull(FRoot.GetNext(C));
  // add after delete of last node
  A := HTMLDiv('', 'x').AppendTo(FRoot);
  AssertTrue(FRoot.GetNext(C) = A);
end;

procedure TTestTree.TestClearKeepsSiblings;
var
  A, B: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(FRoot);
  HTMLDiv('').AppendTo(A);
  A.Clear;
  AssertEquals(0, A.ChildCount);
  AssertTrue(FRoot.GetNext(A) = B);
  AssertEquals(2, FRoot.ChildCount);
end;

procedure TTestTree.TestMoveNodeToAnotherParent;
var
  A, B, C: THtmlNode;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(FRoot);
  C := HTMLDiv('').AppendTo(A);
  B.AddNode(C);
  AssertEquals(0, A.ChildCount);
  AssertEquals(1, B.ChildCount);
  AssertTrue(C.ParentNode = B);
  AssertNull(A.FirstChild);
end;

procedure TTestTree.TestAddParentAsChildRaises;
var
  A, B: THtmlNode;
  Raised: Boolean;
begin
  A := HTMLDiv('').AppendTo(FRoot);
  B := HTMLDiv('').AppendTo(A);
  Raised := False;
  try
    B.AddNode(A);
  except
    Raised := True;
  end;
  AssertTrue(Raised);
end;

procedure TTestTree.TestGetElementsByClassName;
var
  A, B: THtmlNode;
  Arr: THtmlNodeArray;
begin
  A := HTMLDiv('').SetClass('btn primary').AppendTo(FRoot);
  B := HTMLDiv('').SetClass('btn').AppendTo(A);
  HTMLDiv('').SetClass('other').AppendTo(FRoot);
  Arr := FRoot.GetElementsByClassName('btn');
  AssertEquals(2, Length(Arr));
  AssertTrue(Arr[0] = A);
  AssertTrue(Arr[1] = B);
end;

procedure TTestTree.TestGetElementById;
var
  B: THtmlNode;
begin
  HTMLDiv('', 'a').AppendTo(FRoot);
  B := HTMLDiv('', 'b').AppendTo(FRoot.FirstChild);
  AssertTrue(FRoot.GetElementById('b') = B);
  AssertNull(FRoot.GetElementById('none'));
end;

procedure TTestTree.TestClassList;
begin
  FRoot.SetClass('p-4  flex   p-4 items-center');
  AssertEquals(3, FRoot.ClassList.Count);
  AssertEquals('p-4 flex items-center', FRoot.ClassList.Name);
  FRoot.ClassList.Toggle('flex').Add('gap-2').Replace('p-4', 'p-2');
  AssertEquals('p-2 items-center gap-2', FRoot.ClassList.Name);
  AssertTrue(FRoot.ClassList.Contains('gap-2'));
end;

procedure TTestTree.TestStyleValues;
begin
  FRoot.InlineStyle := 'width:10px; color: red';
  AssertEquals('red', FRoot.Style['color']);
  FRoot.Style['width'] := '20px';
  FRoot.Style['height'] := '5px';
  AssertEquals('20px', FRoot.Style['width']);
  AssertEquals(20, FRoot.CompStyle.Width.Value, 0.001);
  AssertEquals(5, FRoot.CompStyle.Height.Value, 0.001);
  FRoot.Style['color'] := '';
  AssertEquals('', FRoot.Style['color']);
end;

procedure TTestTree.TestUserData;
var
  N: THtmlNode;
  Owned, Shared: TFreeSpy;
  OwnedFreed, SharedFreed: Boolean;
begin
  OwnedFreed := False;
  SharedFreed := False;
  Owned := TFreeSpy.Create;
  Owned.FFreed := @OwnedFreed;
  Shared := TFreeSpy.Create;
  Shared.FFreed := @SharedFreed;
  N := HTMLNode('').AppendTo(FRoot);
  N.Tag := 42;
  N.Attributes['data-name'] := 'Peter';
  N.Data := Owned;
  N.OwnsData := True;
  HTMLNode('').AppendTo(FRoot).Data := Shared;     // reference only, not owned
  AssertEquals('tag', 42, FRoot.FirstChild.Tag);
  AssertEquals('text', 'Peter', FRoot.FirstChild.Attributes['data-name']);
  AssertTrue('object', FRoot.FirstChild.Data = Owned);
  FRoot.Clear;                                      // eg. new html replaces nodes
  AssertTrue('owned data is freed with node', OwnedFreed);
  AssertFalse('not owned data stays', SharedFreed);
  Shared.Free;
end;

procedure TTestTree.TestInsertBefore;
var
  A, B, C, D: THtmlNode;
  function Order: String;
  var
    N: THtmlNode;
  begin
    Result := '';
    N := FRoot.FirstChild;
    while Assigned(N) do begin
      Result := Result + N.Id;
      N := FRoot.GetNext(N);
    end;
  end;
begin
  A := HTMLNode('').SetId('a').AppendTo(FRoot);
  B := HTMLNode('').SetId('b').AppendTo(FRoot);
  C := HTMLNode('').SetId('c').AppendTo(FRoot);
  FRoot.InsertBefore(C, A);
  AssertEquals('to first', 'cab', Order);
  FRoot.InsertBefore(C, B);
  AssertEquals('to middle', 'acb', Order);
  FRoot.InsertBefore(A, nil);
  AssertEquals('append', 'cba', Order);
  D := HTMLNode('').SetId('d');
  FRoot.InsertBefore(D, B);
  AssertEquals('new node', 'cdba', Order);
  AssertEquals('count', 4, FRoot.ChildCount);
  AssertTrue('last', FRoot.GetNext(B) = A);
  AssertTrue('prev of first', FRoot.FirstChild = C);
end;

initialization
  RegisterTest(TTestTree);
end.
