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
    FShape: TCSSShape;
    FSheet: TCSSStyleSheet;
    FStatus: TLabel;
    FControls: TList;      // LCL controls created by scene
    procedure ListClick(Sender: TObject);
    procedure NodeClick(Sender: TObject);
    procedure ToggleClick(Sender: TObject);
    procedure PasswordClick(Sender: TObject);
    procedure ClearScene;
    procedure ShowScene(AIndex: Integer);
    procedure SetupScene(ANode: THtmlNode);
    procedure SetChecked(ANode: THtmlNode; AChecked: Boolean);
    function AddControl(AControl: TControl): TControl;
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
  Width := 1100;
  Height := 760;
  Position := poScreenCenter;
  Color := clWhite;
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
  FStatus.Caption := 'Click on buttons in scenes, scroll with mouse wheel or by dragging scrollbars';

  // shape fills the window, content is scrolled by renderer (overflow-y: auto of body)
  FSheet := TCSSStyleSheet.Create(Self);
  FShape := TCSSShape.Create(Self);
  FShape.Parent := Self;
  FShape.Align := alClient;
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

(*
  Nodes with data-active classes: checkbox, switch, radio group (data-group)
*)
procedure TDemoForm.SetChecked(ANode: THtmlNode; AChecked: Boolean);
begin
  if AChecked then begin
    ANode.SetClass(ANode.Attributes['data-base'] + ' ' + ANode.Attributes['data-active']);
    ANode.Attributes['data-checked'] := '1';
  end else begin
    ANode.SetClass(ANode.Attributes['data-base']);
    ANode.Attributes['data-checked'] := '';
  end;
end;

procedure TDemoForm.ToggleClick(Sender: TObject);
var
  Node, N: THtmlNode;
  Group: String;
begin
  Node := THtmlNode(Sender);
  Group := Node.Attributes['data-group'];
  if Group <> '' then begin
    N := FShape.Body;
    while Assigned(N) do begin
      if N.Attributes['data-group'] = Group then SetChecked(N, N = Node);
      N := N.GetNext(N, True);
    end;
  end else
    SetChecked(Node, Node.Attributes['data-checked'] <> '1');
  FShape.Changed;
end;

(*
  "Show" button inside of password input
*)
procedure TDemoForm.PasswordClick(Sender: TObject);
var
  Node, N: THtmlNode;
begin
  Node := THtmlNode(Sender);
  N := Node.ParentNode.FirstChild;
  while Assigned(N) do begin
    if N.AlignControl is TEdit then
      with TEdit(N.AlignControl) do begin
        if PasswordChar = #0 then PasswordChar := '*' else PasswordChar := #0;
        if PasswordChar = #0 then Node.Text := 'Hide' else Node.Text := 'Show';
      end;
    N := N.ParentNode.GetNext(N);
  end;
  FShape.Changed;
end;

function TDemoForm.AddControl(AControl: TControl): TControl;
begin
  AControl.Parent := Self;
  FControls.Add(AControl);
  Result := AControl;
end;

(*
  Background color behind node (for LCL controls without border)
*)
function BackdropColor(ANode: THtmlNode): TColor;
begin
  Result := clWhite;
  while Assigned(ANode) do begin
    if (ANode.CompStyle.Background.Color.ColorType = cctNormal) and (ANode.CompStyle.Background.Color.Alpha = 255) then
      Exit(ANode.CompStyle.Background.Color.Value);
    ANode := ANode.ParentNode;
  end;
end;

(*
  Interactive parts of scene: LCL controls (data-lcl), toggles (data-active), actions, click handlers
*)
procedure TDemoForm.SetupScene(ANode: THtmlNode);
var
  Kind, S: String;
  Edit: TEdit;
  Memo: TMemo;
  Combo: TComboBox;
  Items: TStringList;
  ActiveCls: TStringList;
  I: Integer;
begin
  while Assigned(ANode) do begin
    Kind := ANode.Attributes['data-lcl'];
    if Kind = 'edit' then begin
      Edit := TEdit(AddControl(TEdit.Create(Self)));
      Edit.BorderStyle := bsNone;
      Edit.TextHint := ANode.Attributes['placeholder'];
      Edit.Color := BackdropColor(ANode);
      if ANode.Attributes['data-password'] <> '' then Edit.PasswordChar := '*';
      ANode.Text := '';
      ANode.SetAlignControl(Edit);
    end else
    if Kind = 'memo' then begin
      Memo := TMemo(AddControl(TMemo.Create(Self)));
      Memo.BorderStyle := bsNone;
      Memo.Color := BackdropColor(ANode);
      Memo.WordWrap := True;
      ANode.Text := '';
      ANode.SetAlignControl(Memo);
    end else
    if Kind = 'combo' then begin
      Combo := TComboBox(AddControl(TComboBox.Create(Self)));
      Combo.Style := csDropDownList;
      Items := TStringList.Create;
      try
        Items.Delimiter := '|';
        Items.StrictDelimiter := True;
        Items.DelimitedText := ANode.Attributes['data-items'];
        Combo.Items.Assign(Items);
      finally
        Items.Free;
      end;
      Combo.ItemIndex := 0;
      ANode.Text := '';
      ANode.SetAlignControl(Combo);
    end;
    if ANode.Attributes['data-active'] <> '' then begin
      // base classes = classes without active classes
      ActiveCls := TStringList.Create;
      try
        ActiveCls.Delimiter := ' ';
        ActiveCls.DelimitedText := ANode.Attributes['data-active'];
        S := '';
        for I := 0 to ANode.ClassList.Count - 1 do
          if ActiveCls.IndexOf(ANode.ClassList.Item[I]) < 0 then S := Trim(S + ' ' + ANode.ClassList.Item[I]);
      finally
        ActiveCls.Free;
      end;
      ANode.Attributes['data-base'] := S;
      ANode.OnClick := @ToggleClick;
    end else
    if ANode.Attributes['data-action'] = 'toggle-password' then
      ANode.OnClick := @PasswordClick
    else
    if (ANode.Text <> '') and ANode.ClassList.Contains('cursor-pointer') then
      ANode.OnClick := @NodeClick;
    SetupScene(ANode.FirstChild);
    ANode := ANode.GetNext(ANode);
  end;
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
  FShape.Body.SetScroll(0, 0);
  FSheet.Style := '';
end;

procedure TDemoForm.ShowScene(AIndex: Integer);
begin
  ClearScene;
  if AIndex <= High(DEMO_SCENES) then
    DEMO_SCENES[AIndex].Build(FShape.Body, FSheet)
  else
    BuildControlsScene;
  FShape.Body.InlineStyle := 'overflow-y: auto';    // page is scrolled by renderer
  FShape.Body.ApplyStyles;
  SetupScene(FShape.Body.FirstChild);
  FShape.Body.ApplyStyles;
  FShape.Changed;
end;

(*
  LCL controls aligned inside nodes
*)
procedure TDemoForm.BuildControlsScene;
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
