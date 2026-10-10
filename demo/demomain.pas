unit demomain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  cssbase, CSSCtrls, csstailwind, demoscenes;

type

  { TDemoForm }

  TDemoForm = class(TForm)
  private
    FList: TListBox;
    FScroll: TScrollBox;
    FShape: TCSSShape;
    FSheet: TCSSStyleSheet;
    FStatus: TLabel;
    FControls: TList;      // LCL controls created by scene
    procedure ListClick(Sender: TObject);
    procedure NodeClick(Sender: TObject);
    procedure ClearScene;
    procedure ShowScene(AIndex: Integer);
    procedure BuildControlsScene;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
  end;

var
  DemoForm: TDemoForm;

implementation

{ TDemoForm }

constructor TDemoForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  I: Integer;
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'csscontrols demo';
  Width := 1000;
  Height := 700;
  Position := poScreenCenter;
  FControls := TList.Create;

  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alLeft;
  FList.Width := 160;
  for I := 0 to High(DEMO_SCENES) do FList.Items.Add(DEMO_SCENES[I].Name);
  FList.Items.Add('LCL controls');
  FList.OnClick := @ListClick;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.BorderSpacing.Around := 4;
  FStatus.Caption := 'Click on buttons in scenes';

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.HorzScrollBar.Visible := False;
  FScroll.Color := clWhite;

  FSheet := TCSSStyleSheet.Create(Self);
  FShape := TCSSShape.Create(Self);
  FShape.Parent := FScroll;
  FShape.Align := alTop;
  FShape.AutoSize := True;
  FShape.Body.StyleSheet := FSheet;

  I := 0;
  if ParamCount >= 1 then I := StrToIntDef(ParamStr(1), 0);   // start scene index
  if (I < 0) or (I >= FList.Count) then I := 0;
  FList.ItemIndex := I;
  ShowScene(I);
end;

destructor TDemoForm.Destroy;
begin
  ClearScene;
  FControls.Free;
  inherited Destroy;
end;

procedure TDemoForm.ListClick(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then ShowScene(FList.ItemIndex);
end;

procedure TDemoForm.NodeClick(Sender: TObject);
begin
  FStatus.Caption := 'Clicked: ' + THtmlNode(Sender).Text;
end;

procedure TDemoForm.ClearScene;
var
  I: Integer;
begin
  for I := 0 to FControls.Count - 1 do TControl(FControls[I]).Free;
  FControls.Clear;
  FShape.Body.Clear;
  FShape.Body.SetClass('');
  FShape.Body.InlineStyle := '';
  FShape.Body.Id := 'body';
  FSheet.Style := '';
end;

procedure TDemoForm.ShowScene(AIndex: Integer);
  procedure SetClickHandlers(ANode: THtmlNode);
  begin
    while Assigned(ANode) do begin
      if (ANode.Text <> '') and ANode.ClassList.Contains('cursor-pointer') then ANode.OnClick := @NodeClick;
      SetClickHandlers(ANode.FirstChild);
      ANode := ANode.GetNext(ANode);
    end;
  end;
begin
  ClearScene;
  if AIndex <= High(DEMO_SCENES) then
    DEMO_SCENES[AIndex].Build(FShape.Body, FSheet)
  else
    BuildControlsScene;
  SetClickHandlers(FShape.Body.FirstChild);
  FShape.Body.ApplyStyles;
  FShape.Changed;
end;

(*
  LCL controls aligned inside nodes
*)
procedure TDemoForm.BuildControlsScene;
  function AddControl(AControl: TControl): TControl;
  begin
    AControl.Parent := FScroll;
    FControls.Add(AControl);
    Result := AControl;
  end;
var
  Form, Row: THtmlNode;
  Edit: TEdit;
  Check: TCheckBox;
  Btn: TButton;
begin
  FShape.Body.SetClass('p-8 bg-slate-100');
  Form := HTMLNode('max-w-md mx-auto p-6 bg-white rounded-xl border border-slate-200 flex flex-col gap-4').AppendTo(FShape.Body);
  HTMLNode('text-xl font-semibold text-slate-900', 'Sign in').AppendTo(Form);

  HTMLNode('text-sm font-medium text-slate-700', 'E-mail').AppendTo(Form);
  Edit := TEdit(AddControl(TEdit.Create(Self)));
  Edit.TextHint := 'name@example.com';
  HTMLNode('h-8').SetAlignControl(Edit).AppendTo(Form);

  HTMLNode('text-sm font-medium text-slate-700', 'Password').AppendTo(Form);
  Edit := TEdit(AddControl(TEdit.Create(Self)));
  Edit.PasswordChar := '*';
  HTMLNode('h-8').SetAlignControl(Edit).AppendTo(Form);

  Row := HTMLNode('flex items-center justify-between').AppendTo(Form);
  Check := TCheckBox(AddControl(TCheckBox.Create(Self)));
  Check.Caption := 'Remember me';
  HTMLNode('').SetAlignControl(Check).AppendTo(Row);
  HTMLNode('text-sm text-indigo-600 hover:underline cursor-pointer', 'Forgot password?').AppendTo(Row);

  Btn := TButton(AddControl(TButton.Create(Self)));
  Btn.Caption := 'Sign in';
  HTMLNode('h-9').SetAlignControl(Btn).AppendTo(Form);
end;

end.
