unit demomain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Menus,
  cssbase, CSSCtrls, csstailwind, demoscenes, csscomponents;

type

  { TDemoForm }

  TDemoForm = class(TForm)
  private
    FList: TListBox;
    FInspect: TCheckBox;
    FDark: TCheckBox;
    FShape: TCSSShape;
    FSheet: TCSSStyleSheet;
    FStatus: TLabel;
    FControls: TList;      // LCL controls created by scene
    FSelectMenu: TPopupMenu;
    FSelectNode: THtmlNode;
    procedure InspectClick(Sender: TObject);
    procedure DarkChange(Sender: TObject);
    procedure UpdateControlColors;
    procedure ShapeInspect(Sender: TObject; ANode: THtmlNode);
    procedure SelectClick(Sender: TObject);
    procedure SelectItemClick(Sender: TObject);
    procedure PhoneChange(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure ButtonClick(Sender: TObject);
    procedure ComponentChange(Sender: TObject);
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

function BackdropColor(ANode: THtmlNode): TColor; forward;

{ TDemoForm }

constructor TDemoForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  I: Integer;
  Panel: TPanel;
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'csscontrols demo';
  Width := 1100;
  Height := 760;
  Position := poScreenCenter;
  Color := clWhite;
  FControls := TList.Create;

  Panel := TPanel.Create(Self);
  Panel.Parent := Self;
  Panel.Align := alLeft;
  Panel.Width := 160;
  Panel.BevelOuter := bvNone;
  FInspect := TCheckBox.Create(Self);
  FInspect.Parent := Panel;
  FInspect.Align := alBottom;
  FInspect.BorderSpacing.Around := 6;
  FInspect.Caption := 'Inspect (debug)';
  FInspect.OnClick := @InspectClick;
  FDark := TCheckBox.Create(Self);
  FDark.Parent := Panel;
  FDark.Align := alBottom;
  FDark.BorderSpacing.Around := 6;
  FDark.Caption := 'Dark mode';
  FDark.OnChange := @DarkChange;
  FList := TListBox.Create(Self);
  FList.Parent := Panel;
  FList.Align := alClient;
  for I := 0 to High(DEMO_SCENES) do FList.Items.Add(DEMO_SCENES[I].Name);
  FList.Items.Add('Components');
  FList.OnClick := @ListClick;
  FSelectMenu := TPopupMenu.Create(Self);

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
  FShape.OnInspect := @ShapeInspect;

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

(*
  dark: variant of utility classes for all shapes; native LCL controls get colors of their nodes
*)
procedure TDemoForm.DarkChange(Sender: TObject);
begin
  if CSSDarkMode = FDark.Checked then Exit;
  CSSSetDarkMode(FDark.Checked);
  UpdateControlColors;
end;

procedure TDemoForm.UpdateControlColors;
var
  N: THtmlNode;
begin
  N := FShape.Body;
  while Assigned(N) do begin
    if N.AlignControl is TCustomEdit then begin
      TCustomEdit(N.AlignControl).Color := BackdropColor(N);
      if CSSDarkMode then TCustomEdit(N.AlignControl).Font.Color := RGBToColor(226, 232, 240)
        else TCustomEdit(N.AlignControl).Font.Color := clDefault;
    end;
    N := N.GetNext(N, True);
  end;
end;

procedure TDemoForm.InspectClick(Sender: TObject);
begin
  FShape.Inspect := FInspect.Checked;
  if FInspect.Checked then FStatus.Caption := 'Inspect: move mouse over nodes';
end;

(*
  Box model of node under mouse in Inspect mode
*)
procedure TDemoForm.ShapeInspect(Sender: TObject; ANode: THtmlNode);
  function Sides(const R: TRect): String;
  begin
    if (R.Left = R.Top) and (R.Right = R.Top) and (R.Bottom = R.Top) then Result := IntToStr(R.Top)
      else Result := Format('%d %d %d %d', [R.Top, R.Right, R.Bottom, R.Left]);
  end;
var
  S: String;
  I: Integer;
begin
  if ANode = nil then begin
    FStatus.Caption := 'Inspect: move mouse over nodes';
    Exit;
  end;
  S := ANode.Element;
  if ANode.Id <> '' then S := S + '#' + ANode.Id;
  for I := 0 to ANode.ClassList.Count - 1 do S := S + '.' + ANode.ClassList.Item[I];
  with ANode.CompSize do
    FStatus.Caption := Format('%s   x %d  y %d   %d x %d   margin %s   border %s   padding %s', [S,
      ContentRect.Left, ContentRect.Top, ContentRect.Width, ContentRect.Height, Sides(Margin), Sides(Border), Sides(Padding)]);
end;

(*
  Dropdown styled with utility classes, items are shown in popup menu
*)
procedure TDemoForm.SelectClick(Sender: TObject);
var
  Items: TStringList;
  Item: TMenuItem;
  I: Integer;
  R: TRect;
  P: TPoint;
begin
  FSelectNode := THtmlNode(Sender);
  FSelectMenu.Items.Clear;
  Items := TStringList.Create;
  try
    Items.Delimiter := '|';
    Items.StrictDelimiter := True;
    Items.DelimitedText := FSelectNode.Attributes['data-items'];
    for I := 0 to Items.Count - 1 do begin
      Item := TMenuItem.Create(FSelectMenu);
      Item.Caption := Items[I];
      Item.Checked := Items[I] = FSelectNode.FirstChild.Text;
      Item.OnClick := @SelectItemClick;
      FSelectMenu.Items.Add(Item);
    end;
  finally
    Items.Free;
  end;
  R := FSelectNode.TransformedBounds(FSelectNode.CompSize.ContentRect);   // scrolled position
  P := FShape.ClientToScreen(Point(R.Left, R.Bottom + 4));
  FSelectMenu.PopUp(P.X, P.Y);
end;

procedure TDemoForm.SelectItemClick(Sender: TObject);
begin
  if FSelectNode = nil then Exit;
  FSelectNode.FirstChild.Text := TMenuItem(Sender).Caption;
  FShape.Changed;
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
  if Node.Attributes['data-checked'] = '1' then FStatus.Caption := 'Toggle: on' else FStatus.Caption := 'Toggle: off';
  // theme cards of Settings scene switch dark mode
  if Node.Attributes['data-theme'] = 'dark' then FDark.Checked := True
  else if Node.Attributes['data-theme'] = 'light' then FDark.Checked := False;
  FShape.Body.ApplyStyles;     // styles of children can depend on classes of node (stylesheet rules)
  FShape.Changed;
end;

(*
  Value of LCL control in node: read the control (TEdit.Text), react with its events (OnChange).
  Phone is validated while typing: classes of wrapper node and error message are changed.
*)
procedure TDemoForm.PhoneChange(Sender: TObject);
var
  Node, Wrap, Msg: THtmlNode;
  Digits, I: Integer;
  S: String;
begin
  Node := FShape.Body.GetElementById('phone');
  if Node = nil then Exit;
  S := TEdit(Sender).Text;
  Digits := 0;
  for I := 1 to Length(S) do if S[I] in ['0'..'9'] then Inc(Digits);
  Wrap := Node.ParentNode;
  Msg := Wrap.ParentNode.GetNext(Wrap);      // error message below input
  if Digits >= 9 then begin
    Wrap.ClassList.Name := StringReplace(StringReplace(Wrap.ClassList.Name, 'border-rose-400', 'border-emerald-500', []),
      'focus-within:ring-rose-100', 'focus-within:ring-emerald-100', []);
    if Assigned(Msg) then Msg.SetClass('hidden');
  end else begin
    Wrap.ClassList.Name := StringReplace(StringReplace(Wrap.ClassList.Name, 'border-emerald-500', 'border-rose-400', []),
      'focus-within:ring-emerald-100', 'focus-within:ring-rose-100', []);
    if Assigned(Msg) then Msg.SetClass('flex items-center gap-1.5 text-xs text-rose-600');
  end;
  FShape.Body.ApplyStyles;
  FShape.Changed;
end;

(*
  Values of all inputs (TEdit, TMemo) in scene
*)
procedure TDemoForm.SaveClick(Sender: TObject);
var
  N: THtmlNode;
  S: String;
begin
  S := '';
  N := FShape.Body;
  while Assigned(N) do begin
    if N.AlignControl is TCustomEdit then
      S := S + N.Attributes['placeholder'] + ' = "' + TCustomEdit(N.AlignControl).Text + '"   ';
    N := N.GetNext(N, True);
  end;
  FStatus.Caption := 'Saved: ' + S;
end;

procedure TDemoForm.ButtonClick(Sender: TObject);
begin
  FStatus.Caption := 'TCSSButton clicked: ' + TCSSButton(Sender).Caption;
end;

procedure TDemoForm.ComponentChange(Sender: TObject);
begin
  if Sender is TCSSToggle then
    FStatus.Caption := 'TCSSToggle.Checked = ' + BoolToStr(TCSSToggle(Sender).Checked, True)
  else if Sender is TCSSTabs then
    FStatus.Caption := 'TCSSTabs.TabIndex = ' + IntToStr(TCSSTabs(Sender).TabIndex);
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
      if ANode.Id = 'phone' then Edit.OnChange := @PhoneChange;
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
    if Kind = 'select' then
      ANode.OnClick := @SelectClick;
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
    if ANode.Attributes['data-action'] = 'save' then
      ANode.OnClick := @SaveClick
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
  FSelectNode := nil;
  FShape.Body.Clear;
  FShape.Body.SetClass('');
  FShape.Body.InlineStyle := '';
  FShape.Body.Id := 'body';
  FShape.Body.SetScroll(0, 0);
  FSheet.Style := '';
end;

procedure TDemoForm.ShowScene(AIndex: Integer);
begin
  CSSBeginUpdate;     // many nodes are created: layout once at the end
  try
    ClearScene;
    if AIndex <= High(DEMO_SCENES) then
      DEMO_SCENES[AIndex].Build(FShape.Body, FSheet)
    else
      BuildControlsScene;
    AddDarkVariants(FShape.Body);       // dark: classes for scenes without own dark: classes
    FShape.Body.InlineStyle := 'overflow-y: auto';    // page is scrolled by renderer
    SetupScene(FShape.Body.FirstChild);
    FShape.Body.ApplyStyles;
  finally
    CSSEndUpdate;
  end;
  FShape.Changed;
  UpdateControlColors;
end;

(*
  LCL controls aligned inside nodes
*)
(*
  LCL controls aligned inside nodes and components of csscomponents.pas (TCSSShape descendants)
*)
procedure TDemoForm.BuildControlsScene;
const
  CARD_CLS = 'p-6 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 flex flex-col gap-4';
  LABEL_CLS = 'text-sm font-medium text-slate-700 dark:text-slate-300';
var
  Card, Row: THtmlNode;
  Edit: TEdit;
  Check: TCheckBox;
  Btn: TButton;
  Toggle: TCSSToggle;
  Tabs: TCSSTabs;
  I: Integer;
  procedure Place(AControl: TControl; const AClass: String);
  begin
    HTMLNode(AClass).SetAlignControl(AddControl(AControl)).AppendTo(Row);
  end;
  procedure AddButton(const ACaption: String; AKind: TCSSButtonKind);
  var
    B: TCSSButton;
  begin
    B := TCSSButton.Create(Self);
    B.Caption := ACaption;
    B.Kind := AKind;
    B.OnClick := @ButtonClick;
    Place(B, 'w-24 h-10');
  end;
  procedure AddBadge(const ACaption: String; AColor: TCSSColorName);
  var
    B: TCSSBadge;
  begin
    B := TCSSBadge.Create(Self);
    B.Caption := ACaption;
    B.ColorName := AColor;
    Place(B, 'w-20 h-6');
  end;
  procedure AddAvatar(const AInitials: String; AColor: TCSSColorName; ASize: Integer);
  var
    A: TCSSAvatar;
  begin
    A := TCSSAvatar.Create(Self);
    A.Initials := AInitials;
    A.ColorName := AColor;
    Place(A, Format('w-[%dpx] h-[%dpx]', [ASize, ASize]));
  end;
begin
  FShape.Body.SetClass('p-8 bg-slate-100 dark:bg-slate-950 flex flex-col gap-6');

  // LCL controls in nodes
  Card := HTMLNode('max-w-md w-full mx-auto ' + CARD_CLS).AppendTo(FShape.Body);
  HTMLNode('text-xl font-semibold text-slate-900 dark:text-white', 'Sign in (LCL controls in nodes)').AppendTo(Card);
  HTMLNode(LABEL_CLS, 'E-mail').AppendTo(Card);
  Edit := TEdit(AddControl(TEdit.Create(Self)));
  Edit.TextHint := 'name@example.com';
  HTMLNode('h-8').SetAlignControl(Edit).AppendTo(Card);
  HTMLNode(LABEL_CLS, 'Password').AppendTo(Card);
  Edit := TEdit(AddControl(TEdit.Create(Self)));
  Edit.PasswordChar := '*';
  HTMLNode('h-8').SetAlignControl(Edit).AppendTo(Card);
  Row := HTMLNode('flex items-center justify-between').AppendTo(Card);
  Check := TCheckBox.Create(Self);
  Check.Caption := 'Remember me';
  Place(Check, '');
  HTMLNode('text-sm text-indigo-600 hover:underline cursor-pointer', 'Forgot password?').AppendTo(Row);
  Btn := TButton(AddControl(TButton.Create(Self)));
  Btn.Caption := 'Sign in';
  HTMLNode('h-9').SetAlignControl(Btn).AppendTo(Card);

  // components (csscomponents.pas): normal Lazarus components with properties and events
  Card := HTMLNode('max-w-md w-full mx-auto ' + CARD_CLS).AppendTo(FShape.Body);
  HTMLNode('text-xl font-semibold text-slate-900 dark:text-white', 'Components (csscomponents.pas)').AppendTo(Card);
  HTMLNode(LABEL_CLS, 'TCSSButton').AppendTo(Card);
  Row := HTMLNode('flex flex-wrap gap-2').AppendTo(Card);
  AddButton('Save', cbkPrimary);
  AddButton('Cancel', cbkSecondary);
  AddButton('Delete', cbkDanger);
  AddButton('More', cbkGhost);
  HTMLNode(LABEL_CLS, 'TCSSToggle').AppendTo(Card);
  Row := HTMLNode('flex flex-col gap-2').AppendTo(Card);
  for I := 0 to 1 do begin
    Toggle := TCSSToggle.Create(Self);
    if I = 0 then Toggle.Caption := 'Notifications' else Toggle.Caption := 'Weekly summary';
    Toggle.Checked := I = 0;
    Toggle.OnChange := @ComponentChange;
    Place(Toggle, 'w-56 h-7');
  end;
  HTMLNode(LABEL_CLS, 'TCSSBadge, TCSSAvatar').AppendTo(Card);
  Row := HTMLNode('flex flex-wrap items-center gap-2').AppendTo(Card);
  AddBadge('Draft', ccSlate);
  AddBadge('Active', ccGreen);
  AddBadge('Pending', ccAmber);
  AddBadge('Failed', ccRed);
  Row := HTMLNode('flex items-center gap-3').AppendTo(Card);
  AddAvatar('JD', ccIndigo, 48);
  AddAvatar('AK', ccPink, 40);
  AddAvatar('MN', ccGreen, 32);
  AddAvatar('LS', ccAmber, 24);
  HTMLNode(LABEL_CLS, 'TCSSTabs').AppendTo(Card);
  Row := HTMLNode('flex').AppendTo(Card);
  Tabs := TCSSTabs.Create(Self);
  Tabs.OnChange := @ComponentChange;
  Place(Tabs, 'w-64 h-9');
end;

end.
